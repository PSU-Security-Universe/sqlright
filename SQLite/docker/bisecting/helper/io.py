import enum
import os
import re
import shutil
import sys

from helper.data_struct import (
    log_out_line,
    BisectingResults,
    RESULT,
    is_string_only_whitespace,
)
from bi_config import *


class IO:
    total_processed_bug_count_int: int = 0
    all_files_in_dir = []
    is_checked = False

    is_bug_1_checked = False
    is_bug_2_checked = False
    is_bug_3_checked = False
    is_bug_4_checked = False
    is_bug_5_checked = False
    is_bug_6_checked = False
    is_bug_7_checked = False
    is_bug_8_checked = False
    is_bug_9_checked = False
    is_bug_10_checked = False
    is_bug_11_checked = False
    is_bug_12_checked = False
    is_bug_13_checked = False

    @classmethod
    def remove_file_from_abs_path(cls, fd: str):
        os.remove(os.path.join(fd))

    @classmethod
    def read_queries_from_files(
        cls, file_directory: str, is_removed_read: bool = False
    ):

        all_queries = []
        if len(cls.all_files_in_dir) == 0:
            if cls.is_checked:
                return None, "Done"
            cls.is_checked = True
            cur_all_files_in_dir = os.listdir(file_directory)
            cls.all_files_in_dir = [os.path.join(file_directory, fn) for fn in cur_all_files_in_dir]
            cls.all_files_in_dir.sort(key=os.path.getmtime)
            cls.all_files_in_dir = [fn.split("/")[-1] for fn in cls.all_files_in_dir]

        idx = 0
        current_file_d = ""
        for iter_file_d in cls.all_files_in_dir:
            current_file_d = iter_file_d
            idx += 1

            if current_file_d == "":
                continue

            log_out_line("Found bug sample: {}".format(current_file_d))

            current_file_d = os.path.join(file_directory, current_file_d)
            if not os.path.isfile(current_file_d):
                log_out_line("is not file: {}".format(current_file_d))
                continue

            log_out_line("Filename: " + str(current_file_d) + ". \n")
            current_file = open(current_file_d, "r", errors="replace")
            current_file_str = current_file.read()
            current_file_str = re.sub(r"[^\x00-\x7F]+", " ", current_file_str)
            current_file_str = current_file_str.replace(u"\ufffd", " ")
            all_queries.append(current_file_str)
            current_file.close()
            if is_removed_read == True:
                log_out_line("Deleting file name: %s" % (current_file_d))
                os.remove(os.path.join(current_file_d))
            # Only retrive one file at a time.
            if len(all_queries) != 0:
                break
        
        if idx < (len(cls.all_files_in_dir)):
            cls.all_files_in_dir = cls.all_files_in_dir[idx:]
        else:
            cls.all_files_in_dir = []
            cls.is_checked = True

        #log_out_line(
        #    "Finished reading current query files from the bug_samples folder. "
        #)
        return (
            cls._restructured_and_clean_all_queries(all_queries=all_queries),
            current_file_d,
        )

    @classmethod
    def _restructured_and_clean_all_queries(cls, all_queries):
        output_all_queries = []
        buggy_flag = []
        buggy_idx = []

        for queries in all_queries:
            current_queries_in = queries.split("\n")
            current_queries_out = ""
            is_adding = False
            for query in current_queries_in:
                if "RESULT FLAGS" in query:
                    buggy_flag.append(query)
                if "Result string" in query:
                    is_adding = False
                    output_all_queries.append(current_queries_out)
                    current_queries_out = ""
                    continue
                if not re.search(r"\w", query):
                    continue
                if (
                    "Query" in query
                    or query == ";"
                    or query == " "
                    or query == ""
                    or query == "\n"
                ):
                    is_adding = True
                    continue
                if is_adding:
                    current_queries_out += query + " \n"

        # Find out which select is buggy:
        for idx, cur_flag in enumerate(buggy_flag):
            if "0" in cur_flag:
                buggy_idx.append(idx)

        """ Next, separate the SELECT statements into different query sequences.
            If one buggy query contains multiple SELECT oracle mismatch,
            these mismatches could due to different reasons, 
        """
        output_all_queries_tmp = []
        for cur_query in output_all_queries:
            cur_query_l = cur_query.split("SELECT 'BEGIN VERI 0';")
            database_mangagement_queries = cur_query_l[0]
            for i in range(1, len(cur_query_l)):
                output_queries_out = database_mangagement_queries + "SELECT 'BEGIN VERI 0';"
                output_queries_out += cur_query_l[i]
                if (i - 1) >= len(output_all_queries_tmp):
                    new_list_tmp = []
                    new_list_tmp.append(output_queries_out)
                    output_all_queries_tmp.append(new_list_tmp)
                else:
                    output_all_queries_tmp[i-1].append(output_queries_out)
        
        output_all_queries = []
        for idx in buggy_idx:
            if idx < len(output_all_queries_tmp):
                output_all_queries.append(output_all_queries_tmp[idx])

        # print("Debug: printing all the read queries: \n")
        # for cur_output_query in output_all_queries:
            # for cur_query in cur_output_query:
                # print(cur_query)
                # print("\n\n\n")
            # print("\n\n\n\n\n\n\n")

        return output_all_queries

    @classmethod
    def _retrive_all_verifi_queries_matches(
        cls, query_str, veri_begin_regex, veri_end_regex, oracle
    ):

        # Grab all the verification queries.
        queries_out = []
        queries_pairs = []
        begin_idx = []
        end_idx = []
        for m in re.finditer(veri_begin_regex, query_str):
            begin_idx.append(m.end())
        for m in re.finditer(veri_end_regex, query_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_stmt = query_str[begin_idx[i] : end_idx[i]]
            current_stmt = current_stmt.replace("\n", "")
            if current_stmt == "" or current_stmt == " ":
                continue
            queries_pairs.append(current_stmt)
            if len(queries_pairs) == oracle.veri_vari_num:
                queries_out.append(queries_pairs)
                queries_pairs = []

        log_out_line("Veri_stmts are: %s\n" % (str(queries_out)))
        return queries_out

    @classmethod
    def _retrive_all_normal_queries_matches(
        cls, query_str, veri_begin_regex, veri_end_regex
    ):

        begin_idx = []
        end_idx = []

        for m in re.finditer(veri_end_regex, query_str):
            begin_idx.append(m.end())
        for m in re.finditer(veri_begin_regex, query_str):
            end_idx.append(m.start())

        start_of_verification = end_idx[0]
        normal_query = query_str[:start_of_verification]

        end_idx = end_idx[
            1:
        ]  # Ignore the first one. The end_idx has 1 offset shift compare to begin_idx.

        for i in range(min(len(begin_idx), len(end_idx))):
            current_str: str = query_str[begin_idx[i] : end_idx[i]]
            # current_str = current_str.replace('\n', '')
            if is_string_only_whitespace(current_str):
                continue
            normal_query += current_str + "\n"

        # log_out_line("Header is: " + str(normal_query))
        return normal_query

    @classmethod
    def _pretty_print(cls, query, same_idx, oracle):

        log_out_line("Ori query is: \n%s\n" % (query))

        start_of_norec = query.find("SELECT 'BEGIN VERI 0';")

        # header = query[:start_of_norec]
        tail = query[start_of_norec:]

        # lines = tail.splitlines()
        # opt_selects = lines[1::6]
        # unopt_selects = lines[4::6]
        veri_stmts = cls._retrive_all_verifi_queries_matches(
            tail, r"SELECT 'BEGIN VERI [0-9]';", r"SELECT 'END VERI [0-9]';", oracle
        )

        # It is possible to have multiple normal stmts between norec select stmts. Include them to put them into the header of the output.
        header = cls._retrive_all_normal_queries_matches(
            query, r"SELECT 'BEGIN VERI [0-9]';", r"SELECT 'END EXPLAIN [0-9]';"
        )

        new_tail = "\n\n\n"
        effect_idx = 0
        for idx in range(len(veri_stmts)):
            if idx in same_idx:
                continue
            effect_idx += 1
            new_tail += 'SELECT --------- ' + str(effect_idx) + "  "
            for cur_veri_stmt in veri_stmts[idx]:
                new_tail += cur_veri_stmt + "    "
            new_tail += "\n"

        return header + new_tail

    @classmethod
    def _pretty_process(cls, bisecting_result: BisectingResults, oracle):

        if (
            bisecting_result.last_buggy_res_str_l == []
            or bisecting_result.last_buggy_res_str_l == None
        ):
            return

        same_idx = []
        for idx in range(len(bisecting_result.last_buggy_res_flags_l)):
            # Ignore the result with the same output, and ignore the result that are negative. (-1 Error Execution for most cases)
            if bisecting_result.last_buggy_res_flags_l[idx] != RESULT.FAIL:
                same_idx.append(idx)
                continue

        log_out_line("res_flags: %s" % (str(bisecting_result.last_buggy_res_flags_l)))

        log_out_line("same_idx: %s" % (str(same_idx)))

        log_out_line("res: %s" % (str(bisecting_result.last_buggy_res_str_l)))

        pretty_query = []
        for cur_query in bisecting_result.query:
            pretty_query.append(cls._pretty_print(cur_query, same_idx, oracle))
        bisecting_result.query = pretty_query

        same_idx.reverse()
        for idx in same_idx:
            for j in range(len(bisecting_result.last_buggy_res_str_l)):
                if idx >= len(bisecting_result.last_buggy_res_str_l[j]):
                    # sometimes the idx can larger than
                    # the length of last_buggy_res_str_l[j]
                    continue
                bisecting_result.last_buggy_res_str_l[j].pop(idx)

    @classmethod
    def _is_identified_bugs(cls, result: BisectingResults):
        if result.is_bisecting_error:
            # bisect error
            return False
        if (
            result.last_buggy_res_str_l == []
            or result.last_buggy_res_str_l == None
        ):
            # Does not find the buggy output. 
            return False

        if (result.first_buggy_commit_id != "") and (result.first_buggy_commit_id in KNOWN_BUGGY_COMMIT):
            return True

        for cur_query in result.query:
            if "rtree" in cur_query.casefold():
                return False
            for cur_line in cur_query.splitlines():
                if "create table" in cur_line.casefold():
                    if "primary key" in cur_line.casefold() and "without rowid" in cur_line.casefold():
                        # Seventh and Eighth bug pattern:
                        if not cls.is_bug_7_checked:
                            cls.is_bug_7_checked = True
                            return True

                if "alter table" in cur_line.casefold() and "add column" in cur_line.casefold() and "not null" in cur_line.casefold():
                    # Thirteenth bug pattern:
                    if not cls.is_bug_13_checked:
                        cls.is_bug_13_checked = True
                        return True

                if "SELECT ---------" in cur_line:
                    # Found the buggy SELECT statement
                    # "cur_line" is the SELECT statement, "cur_query" is the whole query sequence. 

                    # First bug pattern.
                    if "distinct" in cur_line.casefold() and "unique index" in cur_query.casefold():
                        if not cls.is_bug_1_checked:
                            cls.is_bug_1_checked = True
                            return True

                    # Second bug pattern. 
                    if "join" in cur_line.casefold() and ("likely"  in cur_line.casefold() or "unlikely" in cur_line.casefold()):
                        if not cls.is_bug_2_checked:
                            cls.is_bug_2_checked = True
                            return True

                    # Third bug pattern: in (..) and
                    if "in (" in cur_line.casefold() and "and" in cur_line.casefold():
                        if not cls.is_bug_3_checked:
                            cls.is_bug_3_checked = True
                            return True
                    
                    # Fourth bug pattern: where exists (...)
                    if "where exists (" in cur_line.casefold():
                        if not cls.is_bug_4_checked:
                            cls.is_bug_4_checked = True
                            return True

                    # Fifth and Sixth bug pattern:
                    if "nth_valud" in cur_line.casefold() and "over" in cur_line.casefold():
                        if not cls.is_bug_5_checked:
                            cls.is_bug_5_checked = True
                            return True

                    # Tenth bug pattern:
                    if "like" in cur_line.casefold() and "and" in cur_line.casefold():
                        if not cls.is_bug_10_checked:
                            cls.is_bug_10_checked = True
                            return True

                    # Eleventh bug pattern:
                    if "unique index" in cur_query.casefold() and "is not null" in cur_line.casefold():
                        if not cls.is_bug_11_checked:
                            cls.is_bug_11_checked = True
                            return True

        # All bug pattern mismatched. Skip the bug. 
        return False


                    



    @classmethod
    def write_uniq_bugs_to_files(
            cls, current_bisecting_result: BisectingResults, oracle, dup_count:int, is_non_deter:bool
    ):
        cls._pretty_process(current_bisecting_result, oracle)

        if not cls._is_identified_bugs(current_bisecting_result) and not is_non_deter:
            # If the bug does not match the filter, do not output it to the unique bug folder. 
            print("All bug pattern mismatched. Skip the bug. ")
            return None
        if not os.path.isdir(UNIQUE_BUG_OUTPUT_DIR):
            os.mkdir(UNIQUE_BUG_OUTPUT_DIR)
        current_unique_bug_output = os.path.join(
            UNIQUE_BUG_OUTPUT_DIR,
            "bug_" + str(current_bisecting_result.uniq_bug_id_int),
        )
        if os.path.exists(current_unique_bug_output):
            append_or_write = "a"
        else:
            append_or_write = "w"
        bug_output_file = open(current_unique_bug_output, append_or_write)


        bug_output_file.write('-------------------------------\n\n')
        if current_bisecting_result.uniq_bug_id_int != "Unknown":
            bug_output_file.write(
                "Bug ID: %d, count: %d \n\n" % (current_bisecting_result.uniq_bug_id_int, dup_count)
            )
        else:
            bug_output_file.write("Bug ID: Unknown. \n\n")

        for idx, cur_query in enumerate(current_bisecting_result.query):
            bug_output_file.write("Query %d: \n%s \n\n" % (idx, cur_query))

        if current_bisecting_result.final_res_flag == RESULT.SEG_FAULT:
            bug_output_file.write(
                "Error: The early commit failed to compile, or crashing. Failed to find the bug introduced commit. \n"
            )

        if (
            current_bisecting_result.last_buggy_res_str_l != []
            and current_bisecting_result.last_buggy_res_str_l != None
        ):
            if oracle.multi_exec_num <= 1:
                for i, cur_run_res in enumerate(
                    current_bisecting_result.last_buggy_res_str_l
                ):
                    for j, cur_res in enumerate(cur_run_res):
                        bug_output_file.write("Last Buggy Result Num: %d \n" % j)
                        for k, cur_r in enumerate(cur_res):
                            bug_output_file.write("RES %d: \n%s\n" % (k, cur_r))
            else:
                for j in range(len(current_bisecting_result.last_buggy_res_str_l[0])):
                    bug_output_file.write("Last Buggy Result Num: %d \n" % j)
                    for i in range(len(current_bisecting_result.last_buggy_res_str_l)):
                        bug_output_file.write(
                            "\nBuggy Run ID: %d, Results: \n%s\n"
                            % (i, current_bisecting_result.last_buggy_res_str_l[i][j])
                        )

        else:
            bug_output_file.write(
                "Last buggy results: None. Possibly because the latest commit already fix the bug. \n\n"
            )

        if current_bisecting_result.first_buggy_commit_id != "":
            bug_output_file.write(
                "First buggy commit ID:%s\n\n"
                % current_bisecting_result.first_buggy_commit_id
            )
        else:
            bug_output_file.write("First buggy commit ID:Unknown\n\n")

        if current_bisecting_result.first_corr_commit_id != "":
            bug_output_file.write(
                "First correct (or crashing) commit ID:%s\n\n"
                % current_bisecting_result.first_corr_commit_id
            )
        else:
            bug_output_file.write("First correct commit ID:Unknown\n\n")

        if (
            current_bisecting_result.is_bisecting_error == True
            or current_bisecting_result.bisecting_error_reason != ""
        ):
            bug_output_file.write(
                "Bisecting Error. \n\nBesecting error reason: %s. \n\n\n\n"
                % current_bisecting_result.bisecting_error_reason
            )

        bug_output_file.write("\n\n\n")

        bug_output_file.close()

        return current_unique_bug_output

    @classmethod
    def status_print(cls):
        # from helper.bisecting import Bisect
        print(
            "Currently, we have %d being processed. \n"
            % (cls.total_processed_bug_count_int)
        )

    @classmethod
    def gen_unique_bug_output_dir(cls):
        if os.path.isdir(UNIQUE_BUG_OUTPUT_DIR):
            shutil.rmtree(UNIQUE_BUG_OUTPUT_DIR)
        os.mkdir(UNIQUE_BUG_OUTPUT_DIR)

    @classmethod
    def retrive_results_from_str(cls, begin_sign: str, end_sign: str, result_str: str):
        if (
            result_str.count(begin_sign) < 1
            or result_str.count(end_sign) < 1
            or is_string_only_whitespace(result_str)
            or result_str == ""
        ):
            return (
                None,
                RESULT.ALL_ERROR,
            )  # Missing the outputs from the res_str. Returnning None implying errors.

        # Grab all matching results.
        res_str_out = []
        begin_idx = []
        end_idx = []
        for m in re.finditer(begin_sign, result_str):
            begin_idx.append(m.end())
        for m in re.finditer(end_sign, result_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            cur_res = result_str[begin_idx[i] : end_idx[i]]
            if "Error" in cur_res:
                res_str_out.append("Error")
            else:
                res_str_out.append(cur_res)

        return res_str_out, RESULT.PASS

    @classmethod
    def retrive_existing_commid_id(cls, file_directory: str):
        all_commit_id = []

        uniq_id_count = 0
        while True:
            current_file_d = os.path.join(file_directory, "bug_%d" % uniq_id_count)
            uniq_id_count += 1
            if not os.path.isfile(current_file_d):
                log_out_line("No existing unique bug reports. ")
                break  # Existing unique bugs not found. Give up.
            log_out_line(
                "Detected existing unique bug reports. Filename: "
                + str(current_file_d)
                + ". \n"
            )
            current_file = open(current_file_d, "r", errors="replace")
            current_file_str = current_file.read()
            current_file_str = re.sub(r"[^\x00-\x7F]+", "", current_file_str)
            current_file_str = current_file_str.replace(u"\ufffd", " ")
            current_file_list = current_file_str.split("\n")
            for cur_line in current_file_list:
                if "First buggy commit ID:" in cur_line:
                    cur_commit_id = cur_line.split(":")[1]
                    if cur_commit_id != "Unknown":
                        all_commit_id.append(cur_commit_id)
                        log_out_line("Retrived commit id: %s\n" % (cur_commit_id))
                    break  # To next file.
            current_file.close()

        return all_commit_id
