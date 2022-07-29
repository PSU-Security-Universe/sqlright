import json
import os.path
import re
import sys
from typing import List

import click
from loguru import logger

ONETAB = " " * 4
ONESPACE = " "
default_ir_type = "kUnknown"

saved_ir_type = []

custom_additional_keywords = {
    "/* nothing */",
    "/* Nothing */",
    "/* Nothing*/",
    "/* empty */",
    "/* Empty */",
    "{}",
    # "{",
    # "}",
    "'!'",
    "'.'",
    "%prec",
}

custom_additional_keywords_mapping = {
    "%prec": "",
    # "/* nothing */": "",
    # "/* Nothing */": "",
    # "/* Nothing*/": "",
    # "/* empty */": "",
    # "/* Empty */": "",
}

with open("assets/keywords_mapping.json") as f:
    keywords_mapping = json.load(f)
    keywords_mapping.update(custom_additional_keywords_mapping)

total_keywords = set()
with open("assets/keywords.json") as f:
    total_keywords |= set(json.load(f))
total_keywords |= custom_additional_keywords

total_tokens = set()
if os.path.exists("assets/tokens.json"):
    with open("assets/tokens.json") as f:
        total_tokens |= set(json.load(f))

manually_translation = {
    "opt_returning_type": """
opt_returning_type:

    // The default returning type is CHAR(512). (The max length of 512
    // is chosen so that the returned values are not handled as BLOBs
    // internally. See CONVERT_IF_BIGGER_TO_BLOB.)
    {
        res = new IR(kOptReturningType, OP3("", "", ""));
        $$ = res;
    }

    | RETURNING_SYM cast_type {
        auto tmp1 = $2;
        res = new IR(kOptReturningType, OP3("RETURNING", "", ""), tmp1);
        $$ = res;
    }

;

"""
}


class Token:
    def __init__(self, word, index):
        self.word = word
        self.index = index
        self._is_keyword = None

    @property
    def is_keyword(self):
        if self._is_keyword is not None:
            return self._is_keyword

        if "'" in self.word:
            self._is_keyword = True
            return self._is_keyword

        self._is_keyword = self.word in total_keywords
        return self._is_keyword

    def __str__(self) -> str:
        if self.is_keyword:
            if self.word.startswith("'") and self.word.endswith("'"):
                return self.word.strip("'")
            if self.word in keywords_mapping:
                return keywords_mapping[self.word]

        return self.word

    def __repr__(self) -> str:
        return '{prefix}("{word}")'.format(
            prefix="Keyword" if self.is_keyword else "Token", word=self.word
        )

    def __gt__(self, other):
        other_index = -1
        if isinstance(other, Token):
            other_index = other.index

        return self.index > other_index


def snake_to_camel(word):
    return "".join(x.capitalize() or "_" for x in word.split("_"))


def camel_to_snake(word):
    return "".join(["_" + i.lower() if i.isupper() else i for i in word]).lstrip("_")


def tokenize(line) -> List[Token]:
    line = line.strip()
    if line.startswith("/*") and line.endswith("*/"):
        # HACK for empty grammar eg. /* EMPTY */
        return [Token(line, 0)]

    words = [word.strip() for word in line.split()]
    words = [word for word in words if word]

    token_sequence = []
    for idx, word in enumerate(words):
        if word == "%prec":
            # ignore everything after %prec
            break
        token_sequence.append(Token(word, idx))

    return token_sequence


def repace_special_keyword_with_token(line):
    words = [word.strip() for word in line.split()]
    words = [word for word in words if word]

    seq = []
    for word in words:
        word = word.strip()
        if not word:
            continue
        # if word in keywords_mapping:
        #     word = keywords_mapping[word]

        seq.append(word)

    return " ".join(seq)


def prefix_tabs(text, tabs_num):
    result = []
    text = text.strip()
    for line in text.splitlines():
        result.append(ONETAB * tabs_num + line)
    return "\n".join(result)


def search_next_keyword(token_sequence, start_index):
    curr_token = None
    left_keywords = []

    if start_index > len(token_sequence):
        return curr_token, left_keywords

    # found_token = False
    for idx in range(start_index, len(token_sequence)):
        curr_token = token_sequence[idx]
        if curr_token.is_keyword:
            left_keywords.append(curr_token)
        else:
            # found_token = True
            break

    return curr_token, left_keywords


def ir_type_str_rewrite(cur_types) -> str:
    if cur_types == "":
        return "Unknown"

    cur_types_l = list(cur_types)
    cur_types_l[0] = cur_types_l[0].upper()

    is_upper = False
    for cur_char_idx in range(len(cur_types_l)):
        if cur_types_l[cur_char_idx] == "_":
            is_upper = True
            cur_types_l[cur_char_idx] = ""
            continue
        if is_upper == True:
            is_upper = False
            cur_types_l[cur_char_idx] = cur_types_l[cur_char_idx].upper()

    cur_types = "".join(cur_types_l)
    return cur_types


def translate_single_line(line, parent):
    token_sequence = tokenize(line)

    i = 0
    tmp_num = 1
    body = ""
    need_more_ir = False
    while i < len(token_sequence):
        left_token, left_keywords = search_next_keyword(token_sequence, i)
        logger.debug(f"Left tokens: '{left_token}', Left keywords: '{left_keywords}'")

        right_token, mid_keywords = search_next_keyword(
            token_sequence, left_token.index + 1
        )
        right_keywords = []
        if right_token:
            _, right_keywords = search_next_keyword(
                token_sequence, right_token.index + 1
            )

        left_keywords_str = " ".join(
            [str(token).upper() for token in left_keywords if str(token)]
        )
        mid_keywords_str = " ".join(
            [str(token).upper() for token in mid_keywords if str(token)]
        )
        right_keywords_str = " ".join(
            [str(token).upper() for token in right_keywords if str(token)]
        )

        if need_more_ir:

            body += "PUSH(res);\n"
            body += f"auto tmp{tmp_num} = ${left_token.index+1};" + "\n"
            body += (
                f"""res = new IR({default_ir_type}, OP3("", "{left_keywords_str}", "{mid_keywords_str}"), res, tmp{tmp_num});"""
                + "\n"
            )
            tmp_num += 1

            if right_token and not right_token.is_keyword:
                body += "PUSH(res);\n"
                body += f"auto tmp{tmp_num} = ${right_token.index + 1};" + "\n"
                body += (
                    f"""res = new IR({default_ir_type}, OP3("", "", "{right_keywords_str}"), res, tmp{tmp_num});"""
                    + "\n"
                )
                tmp_num += 1

        elif right_token and right_token.is_keyword == False:
            body += f"auto tmp{tmp_num} = ${left_token.index+1};" + "\n"
            body += f"auto tmp{tmp_num+1} = ${right_token.index+1};" + "\n"
            body += (
                f"""res = new IR({default_ir_type}, OP3("{left_keywords_str}", "{mid_keywords_str}", "{right_keywords_str}"), tmp{tmp_num}, tmp{tmp_num+1});"""
                + "\n"
            )

            tmp_num += 2
            need_more_ir = True
        elif left_token:
            # Only single one keywords here.
            if (
                not body
                and left_token.index == len(token_sequence) - 1
                and token_sequence[left_token.index].word in total_keywords
            ):
                # the only one keywords is a comment
                if left_keywords_str.startswith("/*") and left_keywords_str.endswith(
                    "*/"
                ):
                    # HACK for empty grammar eg. /* EMPTY */
                    left_keywords_str = ""
                body += (
                    f"""res = new IR({default_ir_type}, OP3("{left_keywords_str}", "", ""));"""
                    + "\n"
                )
                break
            body += f"auto tmp{tmp_num} = ${left_token.index+1};" + "\n"
            body += (
                f"""res = new IR({default_ir_type}, OP3("{left_keywords_str}", "{mid_keywords_str}", ""), tmp{tmp_num});"""
                + "\n"
            )

            tmp_num += 1
            need_more_ir = True
        else:
            pass

        compare_tokens = left_keywords + mid_keywords + right_keywords
        if left_token:
            compare_tokens.append(left_token)
        if right_token:
            compare_tokens.append(right_token)

        max_index_token = max(compare_tokens)
        i = max_index_token.index + 1

    if body:
        ir_type_str = ir_type_str_rewrite(parent)
        body = f"k{ir_type_str}".join(body.rsplit(default_ir_type, 1))
        body += "$$ = res;"

    logger.debug(f"Result: \n{body}")
    return body


def find_first_alpha_index(data, start_index):
    for idx, c in enumerate(data[start_index:]):
        if (
            c.isalpha()
            or c == "'"
            or c == "{"
            or c == "/"
            and data[start_index + idx + 1] == "*"
        ):
            return start_index + idx


def remove_original_actions(data):
    left_bracket_stack = []
    # data = remove_comments_if_necessary(data, True)

    clean_data = data
    for idx, ch in enumerate(data):
        if ch == "{" and not (data[idx - 1] == "'" and data[idx + 1] == "'"):
            left_bracket_stack.append(idx)
        elif ch == "}" and not (data[idx - 1] == "'" and data[idx + 1] == "'"):
            left_index = left_bracket_stack.pop()
            right_index = idx + 1
            length = right_index - left_index
            clean_data = (
                clean_data[:left_index] + " " * length + clean_data[right_index:]
            )

            if not left_bracket_stack:
                # keep the outer most bracket for middle action
                left_data = clean_data[:left_index]
                right_data = clean_data[left_index + 2 :]
                is_middle_action = (
                    right_data.strip()
                    and right_data.strip()[0]
                    not in [
                        ";",
                        "|",
                    ]
                    and not right_data.strip().startswith("/*")
                )

                is_empty_action = right_data.strip().startswith(
                    "|"
                ) and left_data.strip().endswith(":")
                if is_middle_action:
                    clean_data = left_data + "{}" + right_data
                elif is_empty_action:
                    clean_data = (
                        clean_data[:left_index]
                        + "{}\n".rjust(length)
                        + clean_data[right_index:]
                    )

    # clean_data = re.sub(r"\{.*?\}", "", data, flags=re.S)
    clean_data = remove_single_line_comment(clean_data)
    return clean_data


def translate_preprocessing(data):
    """Remove comments, and remove the original actions from the parser"""

    """Remove original actions here. """
    data = remove_original_actions(data)

    all_new_data = ""  # not necessary. But it works now, no need to change. :-o
    new_data = ""
    cur_data = ""
    all_lines = data.split("\n")
    idx = -1
    for cur_line in all_lines:
        idx += 1
        if ":" in cur_line and cur_data != "":
            new_data += cur_data + "\n"
            cur_data = " " + cur_line
            all_new_data += new_data
            new_data = ""
        elif "|" in cur_line:
            new_data += cur_data + "\n"
            cur_data = " " + cur_line
        elif cur_line == all_lines[-1]:
            cur_data += " " + cur_line
            new_data += cur_data + "\n"
            all_new_data += new_data
            new_data = ""
        else:
            cur_data += " " + cur_line

    """Remove all semicolon in the statement? """
    all_new_data_l = list(all_new_data)
    semi_loc = all_new_data.rfind(";", 1)
    if semi_loc != -1:
        all_new_data_l[semi_loc] = ""
    all_new_data = "".join(all_new_data_l)

    # all_new_data += ";"
    #
    # with open("draft.txt", "a") as f:
    #     f.write('----------------\n')
    #     f.write(all_new_data)

    """Join comments from multiple lines into one line."""
    all_new_data = join_comments_into_oneline(all_new_data)

    return all_new_data


def remove_comments_inside_statement(text):
    text = text.strip()
    if not (text.startswith("/*") and text.endswith("*/") and text.count("/*") == 1):
        text = remove_comments_if_necessary(text, True)
    return text


def translate(data):

    data = translate_preprocessing(data=data)
    data = data.strip() + "\n"

    parent_element = data[: data.find(":")]
    logger.debug(f"Parent element: '{parent_element}'")

    first_alpha_after_colon = find_first_alpha_index(data, data.find(":"))
    first_child_element = data[
        first_alpha_after_colon : data.find("\n", first_alpha_after_colon)
    ]
    first_child_element = remove_comments_inside_statement(first_child_element)
    first_child_body = translate_single_line(first_child_element, parent_element)

    mapped_first_child_element = repace_special_keyword_with_token(first_child_element)
    logger.debug(f"First child element: '{mapped_first_child_element}'")
    translation = f"""
{parent_element}:

{ONETAB}{mapped_first_child_element}{ONESPACE}{{
{prefix_tabs(first_child_body, 2)}
{ONETAB}}}
"""

    rest_children_elements = [line.strip() for line in data.splitlines() if "|" in line]
    rest_children_elements = [
        line[1:].strip() for line in rest_children_elements if line.startswith("|")
    ]
    for child_element in rest_children_elements:
        child_element = remove_comments_inside_statement(child_element)
        child_body = translate_single_line(child_element, parent_element)

        mapped_child_element = repace_special_keyword_with_token(child_element)
        logger.debug(f"Child element => '{mapped_child_element}'")
        translation += f"""
{ONETAB}|{ONESPACE}{mapped_child_element}{ONESPACE}{{
{prefix_tabs(child_body, 2)}
{ONETAB}}}
"""

    translation += "\n;"

    # fix the IR type to kUnknown
    with open("all_ir_types.txt", "a") as f:
        ir_type_str = ir_type_str_rewrite(parent_element)

        if ir_type_str not in saved_ir_type:
            saved_ir_type.append(ir_type_str)
            f.write(f"V(k{ir_type_str})   \\\n")

        default_ir_type_num = translation.count(default_ir_type)
        for idx in range(default_ir_type_num):
            translation = translation.replace(
                default_ir_type, f"k{ir_type_str}_{idx+1}", 1
            )
            # body = body.replace(default_ir_type, f"k{ir_type_str}", 1)
            if f"{ir_type_str}_{idx+1}" not in saved_ir_type:
                saved_ir_type.append(f"{ir_type_str}_{idx+1}")
                f.write(f"V(k{ir_type_str}_{idx+1})   \\\n")

    logger.info(translation)
    return translation


def get_gram_tokens():
    global total_tokens

    tokens_file = "assets/tokens.y"
    with open(tokens_file) as f:
        token_data = f.read()

    token_data = remove_comments_if_necessary(token_data, True)

    token_data = token_data.splitlines()
    token_data = [line.strip() for line in token_data]
    token_data = [line for line in token_data if line]

    gram_tokens = set()
    for line in token_data:
        line = line.replace("\t", " ")
        line = line.replace(";", "")
        if line.endswith(">"):
            continue

        if line.startswith("%type"):
            line = line.split(" ", 2)[-1:]
            line = " ".join(line)

        line = line.strip()
        gram_tokens |= set(line.split())

    for token in gram_tokens:
        if token.startswith("<"):
            logger.info(token)

    unwanted = [
        "",
        " ",
        "IDENT",
        "IDENT_QUOTED",
        "TEXT_STRING",
        "DECIMAL_NUM",
        "FLOAT_NUM",
        "NUM",
        "LONG_NUM",
        "HEX_NUM",
        "LEX_HOSTNAME",
        "ULONGLONG_NUM",
    ]
    for elem in unwanted:
        if elem in gram_tokens:
            gram_tokens.remove(elem)

    custom_additional_tokens = [
        "group_replication_plugin_auth",
        "opt_with_roles",
        "opt_group_replication_start_options",
        "view_suid",
        "opt_grant_as",
        "change_replication_source_tls_version",
        "equal",
        "table_lock",
        "grant_options",
        "opt_ssl",
        "import_stmt",
        "table_to_table_list",
        "group_replication_user",
        "opt_all",
        "change_replication_source_delay",
        "execute_var_ident",
        "table_or_tables",
        "opt_savepoint",
        "execute_var_list",
        "purge_option",
        "connect_option",
        "change_replication_source_port",
        "opt_if_exists_ident",
        "view_replace",
        "sp_proc_stmt_unlabeled",
        "sp_pdparams",
        "sp_proc_stmt_if",
        "opt_value",
        "sp_proc_stmt_statement",
        "prepare_src",
        "binlog_from",
        "table_to_table",
        "prepare",
        "require_list",
        "sf_tail",
        "source_tls_ciphersuites_def",
        "change_replication_source_auto_position",
        "use",
        "sp_pdparam",
        "sp_block_content",
        "master_or_binary",
        "init_lex_create_info",
        "opt_table",
        "opt_account_lock_password_expire_option",
        "reset",
        "opt_outer",
        "change_replication_source_user",
        "source_file_def",
        "resignal_stmt",
        "opt_of",
        "opt_create_database_options",
        "ev_ends",
        "else_clause_opt",
        "drop_procedure_stmt",
        "opt_column",
        "change_replication_source_get_source_public_key",
        "group_replication_password",
        "not",
        "opt_work",
        "alter_function_stmt",
        "drop_function_stmt",
        "drop_tablespace_stmt",
        "nchar",
        "drop_user_stmt",
        "varchar",
        "opt_default_auth_option",
        "get_diagnostics",
        "create_database_options",
        "searched_case_stmt",
        "view_tail",
        "ignore_server_id_list",
        "opt_INTO",
        "purge",
        "create_user_list",
        "character_set",
        "simple_statement_or_begin",
        "alter_database_stmt",
        "rename_list",
        "opt_storage",
        "change_replication_source_heartbeat_period",
        "sp_fetch_list",
        "drop_undo_tablespace_stmt",
        "event_tail",
        "sp_labeled_block",
        "change_replication_source_tls_ciphersuites",
        "opt_account_lock_password_expire_options",
        "source_reset_options",
        "sp_proc_stmt_open",
        "opt_user_option",
        "view_query_block",
        "grant",
        "require_list_element",
        "opt_user_attribute",
        "group_replication_start_options",
        "flush_options",
        "not2",
        "view_algorithm",
        "checksum",
        "drop_database_stmt",
        "sp_unlabeled_control",
        "start_entry",
        "change_replication_source_connect_retry",
        "change_replication_source",
        "server_option",
        "sp_c_chistic",
        "sp_elseifs",
        "connect_option_list",
        "drop_view_stmt",
        "drop_event_stmt",
        "rollback",
        "assign_gtids_to_anonymous_transactions_def",
        "opt_comma",
        "change_replication_source_ssl_crl",
        "require_clause",
        "sp_hcond_element",
        "view_or_trigger_or_sp_or_event",
        "definer_tail",
        "sp_proc_stmt_close",
        "change_replication_source_ssl_crlpath",
        "revoke",
        "sp_proc_stmt",
        "searched_when_clause_list",
        "connect_options",
        "change_replication_source_ssl_cert",
        "stop_replica_stmt",
        "alter_procedure_stmt",
        "definer_opt",
        "trigger_tail",
        "opt_as",
        "drop_server_stmt",
        "opt_generated_always",
        "definer",
        "no_definer_tail",
        "release",
        "sp_tail",
        "create_database_option",
        "sp_proc_stmt_fetch",
        "commit",
        "flush_option",
        "savepoint",
        "from_or_in",
        "ignore_server_id",
        "sp_proc_stmts1",
        "execute_using",
        "sp_proc_stmt_leave",
        "create",
        "ev_starts",
        "alter_database_options",
        "change_replication_source_public_key",
        "opt_replica_until",
        "deallocate_or_drop",
        "sp_proc_stmts",
        "help",
        "change_replication_source_password",
        "group_replication",
        "deallocate",
        "drop_table_stmt",
        "opt_plugin_dir_option",
        "sp_proc_stmt_return",
        "alter_user_list",
        "sp_c_chistics",
        "alter_database_option",
        "no_definer",
        "change_replication_source_zstd_compression_level",
        "simple_when_clause_list",
        "opt_end_of_input",
        "opt_equal",
        "change_replication_source_retry_count",
        "alter_view_stmt",
        "simple_when_clause",
        "start_replica_stmt",
        "opt_privileges",
        "change_replication_source_ssl_verify_server_cert",
        "reset_options",
        "sp_if",
        "alter_logfile_stmt",
        "flush",
        "alter_undo_tablespace_stmt",
        "start",
        "udf_tail",
        "filter_defs",
        "source_log_pos",
        "privilege_check_def",
        "flush_options_list",
        "sp_fdparam_list",
        "kill_option",
        "ev_sql_stmt_inner",
        "rename",
        "signal_stmt",
        "opt_default",
        "and",
        "source_defs",
        "change_replication_source_ssl_cipher",
        "opt_account_lock_password_expire_option_list",
        "group_replication_start_option",
        "change_replication_source_ssl_ca",
        "unlock",
        "alter_server_stmt",
        "grant_ident",
        "lock",
        "opt_wild",
        "reset_option",
        "opt_and",
        "source_log_file",
        "opt_inner",
        "opt_flush_lock",
        "change_replication_source_ssl_capath",
        "change_replication_source_bind",
        "drop_trigger_stmt",
        "table_primary_key_check_def",
        "key_or_index",
        "purge_options",
        "value_or_values",
        "sp_suid",
        "alter_user_command",
        "begin_stmt",
        "searched_when_clause",
        "drop_logfile_stmt",
        "sp_unlabeled_block",
        "group_replication_start",
        "replica_until",
        "optional_braces",
        "lines_or_rows",
        "opt_primary",
        "change",
        "sp_fdparam",
        "describe_command",
        "kill",
        "table_lock_list",
        "sp_pdparam_list",
        "sp_opt_fetch_noise",
        "keys_or_index",
        "view_replace_or_algorithm",
        "change_replication_source_compression_algorithm",
        "begin_or_start",
        "opt_to",
        "opt_replica_reset_options",
        "dec_num",
        "clone_stmt",
        "case_stmt_specification",
        "xa",
        "opt_PRECISION",
        "ev_sql_stmt",
        "opt_password_option",
        "source_def",
        "alter_event_stmt",
        "binlog_base64_event",
        "install",
        "sp_a_chistics",
        "ev_schedule_time",
        "simple_case_stmt",
        "sp_labeled_control",
        "opt_key_or_index",
        "alter_user_stmt",
        "change_replication_source_ssl_key",
        "sp_chistic",
        "dec_num_error",
        "sql_statement.y.y",
        "execute",
        "sp_proc_stmt_iterate",
        "change_replication_source_ssl",
        "change_replication_source_host",
        "sp_fdparams",
        "nvarchar",
        "alter_tablespace_stmt",
        "filter_def",
        "replica",
        "server_options_list",
        "uninstall",
    ]

    total_tokens |= gram_tokens
    total_tokens |= set(custom_additional_tokens)
    with open("assets/tokens.json", "w") as f:
        json.dump(list(total_tokens), f, indent=2, sort_keys=True)


def get_gram_keywords():
    global total_keywords

    keywords_file = "assets/keywords.y"
    with open(keywords_file) as f:
        keyword_data = f.read()

    keyword_data = remove_comments_if_necessary(keyword_data, True)

    keyword_data = keyword_data.splitlines()
    keyword_data = [line.strip() for line in keyword_data if line.strip()]
    keyword_data = [
        line
        for line in keyword_data
        if not (line.startswith("*") or line.startswith("/"))
    ]

    gram_keywords = set()
    for line in keyword_data:
        line = line.replace("\t", " ")

        if line.startswith("%token") and " <" in line and "> " in line:
            line = line.split(" ", 2)[-1]
        elif line.startswith("%"):
            line = line.split(" ", 1)[-1]

        line = line.strip()
        words = [word for word in line.split() if not word.isdigit()]
        gram_keywords |= set(words)

    unwanted = ["", " "]
    for elem in unwanted:
        if elem in gram_keywords:
            gram_keywords.remove(elem)

    total_keywords |= gram_keywords
    with open("assets/keywords.json", "w") as f:
        json.dump(list(total_keywords), f, indent=2, sort_keys=True)


def join_comments_into_oneline(text):
    clean_text = text

    index = 0
    inside_comment = False
    while index < len(text) - 1:
        lch = text[index]
        rch = text[index + 1]
        if lch == "/" and rch == "*":
            inside_comment = True
        elif lch == "*" and rch == "/":
            inside_comment = False

        if lch == "\n" and inside_comment:
            clean_text = clean_text[:index] + " " + clean_text[index + 1 :]

        index += 1

    return clean_text.strip()


def remove_comments_if_necessary(text, need_remove):
    if not need_remove:
        return text

    left_comment_mark = []
    clean_text = text

    index = 0
    """Remove multiple lines comments."""
    while index < len(text) - 1:
        lch = text[index]
        rch = text[index + 1]
        if lch == "/" and rch == "*":
            left_comment_mark.append(index)
        elif lch == "*" and rch == "/":
            left_index = left_comment_mark.pop()
            right_index = index + 1 + 1
            length = right_index - left_index

            clean_text = (
                clean_text[:left_index] + " " * length + clean_text[right_index:]
            )

        index += 1

    """Remove single line comment"""
    clean_text = remove_single_line_comment(clean_text)
    return clean_text
    # pattern = r"/\*.*?\*/"
    # return re.sub(pattern, "", text, flags=re.S)


def remove_single_line_comment(text):
    clean_text = text
    while "//" in clean_text:
        start_index = clean_text.find("//")
        end_index = clean_text.find("\n", start_index + 1)
        clean_text = clean_text[:start_index] + "\n" + clean_text[end_index:]

    return clean_text.strip()


def select_translate_region(data):
    pattern = "%%"
    start_pos = data.find(pattern) + len(pattern)
    stop_pos = data.find(pattern, start_pos)
    return data[start_pos:stop_pos]


def mark_statement_location(data):
    class Line:
        def __init__(self, lineno, contents):
            self.lineno: int = lineno
            self.contents: str = contents

            words = self.contents.split()
            first_elem: str = words[0] if words else ""
            self.contain_colon = ":" in first_elem
            self.first_word = first_elem.rstrip(":")
            self.first_is_token = self.first_word in total_tokens

        def __repr__(self):
            return f"Line({self.lineno}, {self.first_word})"

    lines = [line.strip() for line in data.splitlines()]
    line_objs = [Line(lineno, contents) for lineno, contents in enumerate(lines)]
    token_objs = [line_obj for line_obj in line_objs if line_obj.contain_colon]
    token_objs = [line_obj for line_obj in token_objs if line_obj.first_is_token]

    token_objs = sorted(token_objs, key=lambda x: x.lineno)

    range_bits = [i for i in range(len(lines))]

    def search_next_semicolon_line(lines, start_index, stop_index):
        partial_lines = lines[start_index:stop_index]
        for relative_index, line in enumerate(partial_lines):
            if line == ";":
                return start_index + relative_index

        # HACK: hack for single line grammar, maybe not accurate
        # if partial_lines[0].endswith(";"):
        #     return start_index

        logger.warning(f"Cannot find next semicolon. {lineno_start} - {lineno_stop}")
        logger.warning(partial_lines)

    extract_tokens = {}
    for idx in range(len(token_objs)):
        token_start = token_objs[idx]
        lineno_start = token_start.lineno

        if idx + 1 == len(token_objs):
            lineno_stop = len(lines)
        else:
            token_stop = token_objs[idx + 1]
            lineno_stop = token_stop.lineno

        semicolon_index = search_next_semicolon_line(lines, lineno_start, lineno_stop)
        if not semicolon_index:
            logger.warning(f"Cannot find next semicolon position. ")

        extract_tokens[token_start.first_word] = "\n".join(
            lines[lineno_start : semicolon_index + 1]
        )

        range_bits[lineno_start] = token_start.first_word
        for j in range(lineno_start + 1, semicolon_index + 1):
            range_bits[j] = False

    marked_lines = []
    for k in range_bits:
        if k == False:
            continue

        if isinstance(k, str):
            marked_lines.append(f"=== {k.strip()} ===")
            continue

        if k:
            marked_lines.append(lines[k])
            continue

        marked_lines.append(lines[k])

    marked_lines = "\n".join(marked_lines)

    return marked_lines, extract_tokens


@click.command()
@click.option("-o", "--output", default="bison_parser_2.y")
@click.option("--remove-comments", is_flag=True, default=False)
def run(output, remove_comments):
    # Remove all_ir_type.txt, if exist
    if os.path.exists("./all_ir_types.txt"):
        os.remove("./all_ir_types.txt")

    data = open("assets/parser_stmts.y").read()

    data = remove_comments_if_necessary(data, remove_comments)
    # data = select_translate_region(data)

    marked_lines, extract_tokens = mark_statement_location(data)

    for token_name, extract_token in extract_tokens.items():
        if token_name in manually_translation:
            translation = manually_translation[token_name]
        else:
            translation = translate(extract_token)

        marked_lines = marked_lines.replace(
            f"=== {token_name.strip()} ===", translation, 1
        )

    with open(output, "w") as f:
        f.write("/*\n")
        f.write(marked_lines)


def get_keywords_mapping():
    with open("assets/lex.h") as f:
        lines = [line.strip() for line in f.readlines()]
        lines = [line for line in lines if line.startswith("{SYM")]

    mapping = {}
    for line in lines:
        matched = line[line.find('"') : line.rfind(")")]
        text, sym = matched.split(",")
        text = text.strip().strip('"')
        sym = sym.strip()
        if sym not in mapping:
            mapping[sym] = text

    additional_mapping = {"END_OF_INPUT": "", "{}": ""}
    mapping.update(additional_mapping)
    with open("assets/keywords_mapping.json", "w") as f:
        json.dump(mapping, f, indent=2, sort_keys=True)


if __name__ == "__main__":
    # get_gram_tokens()
    # get_gram_keywords()
    # get_keywords_mapping()
    run()
