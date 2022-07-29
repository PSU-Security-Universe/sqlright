import re
from sys import maxsize
from enum import Enum

from helper.data_struct import RESULT, is_string_only_whitespace


class VALID_TYPE_TLP(Enum):
    NORM = 1
    MIN = 2
    MAX = 3
    SUM = 4
    COUNT = 5
    AVG = 6
    DISTINCT = 7
    GROUP_BY = 8


class Oracle_TLP:

    multi_exec_num = 1
    veri_vari_num = 2

    @staticmethod
    def retrive_all_results(result_str):
        if (
            result_str.count("BEGIN VERI") < 1
            or result_str.count("END VERI") < 1
            or is_string_only_whitespace(result_str)
            or result_str == ""
        ):
            return (
                None,
                RESULT.ALL_ERROR,
            )  # Missing the outputs from the opt or the unopt. Returnning None implying errors.

        # Grab all the opt results.
        opt_results = []
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"BEGIN VERI 0", result_str):
            begin_idx.append(m.end())
        for m in re.finditer(r"END VERI 0", result_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_opt_result = result_str[begin_idx[i] : end_idx[i]]
            if "Error" in current_opt_result:
                opt_results.append("Error")
            else:
                opt_results.append(current_opt_result)

        # Grab all the unopt results.
        unopt_results = []
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"BEGIN VERI 1", result_str):
            begin_idx.append(m.end())
        for m in re.finditer(r"END VERI 1", result_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_unopt_result = result_str[begin_idx[i] : end_idx[i]]
            if "Error" in current_unopt_result:
                unopt_results.append("Error")
            else:
                unopt_results.append(current_unopt_result)

        all_results_out = []
        for i in range(min(len(opt_results), len(unopt_results))):
            cur_results_out = [opt_results[i], unopt_results[i]]
            all_results_out.append(cur_results_out)

        return all_results_out, RESULT.PASS

    @classmethod
    def comp_query_res(cls, queries_l, all_res_str_l):
        queries = queries_l[0]
        valid_type_list = cls._get_valid_type_list(queries)

        # Has only one run through
        all_res_str_l = all_res_str_l[0]

        all_res_out = []
        final_res = RESULT.PASS

        for idx, valid_type in enumerate(valid_type_list):
            # print(opt_result)
            # if idx >= len(opt_result) or idx >= len(unopt_result):
            #     break
            if valid_type == VALID_TYPE_TLP.NORM:
                curr_res = cls._check_result_norm(
                    all_res_str_l[idx][0], all_res_str_l[idx][1]
                )
                all_res_out.append(curr_res)
            elif (
                valid_type == VALID_TYPE_TLP.DISTINCT
                or valid_type == VALID_TYPE_TLP.GROUP_BY  
            ):
                curr_res = cls._check_result_uniq(
                    all_res_str_l[idx][0], all_res_str_l[idx][1]
                )
                print("\n" + f"Opt: {all_res_str_l[idx][0]}" + "\n" + f"UnOpt: {all_res_str_l[idx][1]}" + "\n" + f"Result: {curr_res}\n")
                # input("wait")
                all_res_out.append(curr_res)
            elif (
                valid_type == VALID_TYPE_TLP.COUNT
                or valid_type == VALID_TYPE_TLP.SUM
                or valid_type == VALID_TYPE_TLP.MIN
                or valid_type == VALID_TYPE_TLP.MAX
                or valid_type == VALID_TYPE_TLP.AVG
            ):
                curr_res = cls._check_result_minmax_count_sum(
                    all_res_str_l[idx][0], all_res_str_l[idx][1], valid_type
                )
                all_res_out.append(curr_res)
            else:
                raise ValueError(
                    "Encounter unknown VALID_TYPE_TLP in the check_query_exec_correctness_under_commitID func. "
                )

        for curr_res_out in all_res_out:
            if curr_res_out == RESULT.FAIL:
                final_res = RESULT.FAIL
                break

        is_all_query_return_errors = True
        for curr_res_out in all_res_out:
            if curr_res_out != RESULT.ERROR:
                is_all_query_return_errors = False
                break
        if is_all_query_return_errors:
            final_res = RESULT.ALL_ERROR

        return final_res, all_res_out

    @classmethod
    def _get_valid_type_list(cls, query: str):
        if (
            query.count("BEGIN VERI") < 1
            or query.count("END VERI") < 1
            or is_string_only_whitespace(query)
            or query == ""
        ):
            return []  # query is not making sense at all.

        # Grab all the opt queries, detect its valid_type, and return.
        valid_type_list = []
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"SELECT 'BEGIN VERI 0';", query):
            begin_idx.append(m.end())
        for m in re.finditer(
            r"SELECT 'END VERI 0';", query
        ):  # Might contains additional unnecessary characters, such as SELECT in the SELECT 97531;
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_opt_query = query[begin_idx[i] : end_idx[i]]
            valid_type_list.append(cls._get_valid_type(current_opt_query))

        return valid_type_list

    @classmethod
    def _get_valid_type(cls, query: str):
        if re.match(
            r"""^[\s;]*SELECT\s*(DISTINCT\s*)(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning valid_type: DISTINCT" % (query.strip()))
            return VALID_TYPE_TLP.DISTINCT
        if re.match(
            r"""^[\s;]*SELECT\s*(.+)(GROUP\s*)(BY\s*)(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning valid_type: GROUP_BY" % (query.strip()))
            return VALID_TYPE_TLP.GROUP_BY
        elif re.match(
            r"""^[\s;]*SELECT\s*MIN(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning valid_type: MIN" % (query.strip()))
            return VALID_TYPE_TLP.MIN
        elif re.match(
            r"""^[\s;]*SELECT\s*MAX(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_TLP: MAX" % (query.strip()))
            return VALID_TYPE_TLP.MAX
        elif re.match(
            r"""^[\s;]*SELECT\s*SUM(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_TLP: SUM" % (query.strip()))
            return VALID_TYPE_TLP.SUM
        elif re.match(
            r"""^[\s;]*SELECT\s*AVG(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_TLP: AVG" % (query.strip()))
            return VALID_TYPE_TLP.AVG
        elif re.match(
            r"""^[\s;]*SELECT\s*COUNT(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_TLP: COUNT" % (query.strip()))
            return VALID_TYPE_TLP.COUNT
        else:
            # print("For query: %s, returning VALID_TYPE_TLP: NORM" % (query.strip()))
            return VALID_TYPE_TLP.NORM

    @classmethod
    def _check_result_norm(cls, opt: str, unopt: str) -> RESULT:
        if "Error" in opt or "Error" in unopt:
            return RESULT.ERROR

        opt_out_int = 0
        unopt_out_int = 0

        opt_list = opt.split("\n")
        unopt_list = unopt.split("\n")

        for cur_opt in opt_list:
            if re.match(
                r"""^[\|\s]*$""", cur_opt, re.MULTILINE | re.IGNORECASE
            ):  # Only spaces or | (separator)
                continue
            opt_out_int += 1
        for cur_unopt in unopt_list:
            if re.match(
                r"""^[\|\s]*$""", cur_unopt, re.MULTILINE | re.IGNORECASE
            ):  # Only spaces or | (separator)
                continue
            unopt_out_int += 1

        if opt_out_int != unopt_out_int:
            # print("NORMAL Mismatched: opt: %s\n unopt: %s\n opt(int): %d, unopt(int): %d" % (opt, unopt, opt_out_int, unopt_out_int) )
            return RESULT.FAIL
        else:
            return RESULT.PASS

    @classmethod
    def _check_result_uniq(cls, opt: str, unopt: str) -> RESULT:
        if "Error" in opt or "Error" in unopt:
            return RESULT.ERROR

        opt_out_int = 0
        unopt_out_int = 0

        opt_list = opt.split("\n")
        unopt_list = unopt.split("\n")
        
        unique_opt_list = set()
        for cur_opt in opt_list:
            if re.match(
                r"""^[\|\s]*$""", cur_opt, re.MULTILINE | re.IGNORECASE
            ):  # Only spaces or | (separator)
                continue
            unique_opt_list.add(cur_opt)
        opt_out_int = len(unique_opt_list)
        
        unique_unopt_list = set()
        for cur_unopt in unopt_list:
            if re.match(
                r"""^[\|\s]*$""", cur_unopt, re.MULTILINE | re.IGNORECASE
            ):  # Only spaces or | (separator)
                continue
            unique_unopt_list.add(cur_unopt)
        unopt_out_int = len(unique_unopt_list)
        
        if opt_out_int != unopt_out_int:
            return RESULT.FAIL
        else:
            return RESULT.PASS


    @classmethod
    def _check_result_minmax_count_sum(cls, opt, unopt, valid_type) -> RESULT:
        if "Error" in opt or "Error" in unopt:
            return RESULT.ERROR

        opt_out_int: int = 0
        unopt_out_int: int = 0
        if valid_type == VALID_TYPE_TLP.MAX:
            opt_out_int = 0
            unopt_out_int = 0
        elif valid_type == VALID_TYPE_TLP.MIN:
            opt_out_int = maxsize
            unopt_out_int = maxsize
        elif valid_type == VALID_TYPE_TLP.AVG:
            opt_out_int = 0
            unopt_out_int = 0
        elif valid_type == VALID_TYPE_TLP.COUNT or valid_type == VALID_TYPE_TLP.SUM:
            opt_out_int = 0
            unopt_out_int = 0
        else:
            raise ValueError(
                "Cannot handle valid_type: "
                + str(valid_type)
                + " in the check_result function. "
            )

        for cur_opt in opt.split("\n"):
            if is_string_only_whitespace(cur_opt):
                continue
            cur_res = 0
            try:
                cur_res = int(cur_opt)
            except ValueError:
                return RESULT.ERROR

            if valid_type == VALID_TYPE_TLP.COUNT or valid_type == VALID_TYPE_TLP.SUM:
                opt_out_int += cur_res
            elif valid_type == VALID_TYPE_TLP.MAX and cur_res > opt_out_int:
                opt_out_int = cur_res
            elif valid_type == VALID_TYPE_TLP.MIN and cur_res < opt_out_int:
                opt_out_int = cur_res

        for cur_unopt in unopt.split("\n"):
            if is_string_only_whitespace(cur_unopt):
                continue
            cur_res = 0
            try:
                cur_res = int(cur_unopt)
            except ValueError:
                return RESULT.ERROR

            if valid_type == VALID_TYPE_TLP.COUNT or valid_type == VALID_TYPE_TLP.SUM:
                unopt_out_int += cur_res
            elif valid_type == VALID_TYPE_TLP.MAX and cur_res > unopt_out_int:
                unopt_out_int = cur_res
            elif valid_type == VALID_TYPE_TLP.MIN and cur_res < unopt_out_int:
                unopt_out_int = cur_res

        if opt_out_int != unopt_out_int:
            # print("UNIQUE Mismatched: opt: %s\n unopt: %s\n opt(int): %d, unopt(int): %d" % (opt, unopt, opt_out_int, unopt_out_int) )
            return RESULT.FAIL
        else:
            return RESULT.PASS
