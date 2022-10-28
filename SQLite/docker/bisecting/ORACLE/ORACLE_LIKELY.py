import re
from enum import Enum
from sys import maxsize

from helper.data_struct import RESULT, is_string_only_whitespace


class VALID_TYPE_LIKELY(Enum):
    NORM = 1
    MIN = 2
    MAX = 3
    SUM = 4
    COUNT = 5
    AVG = 6
    DISTINCT = 7
    GROUP_BY = 8


class Oracle_LIKELY:

    multi_exec_num = 1
    veri_vari_num = 3

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

        # Grab all the ori results.
        ori_result = ""
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"BEGIN VERI 0", result_str):
            begin_idx.append(m.end())
        for m in re.finditer(r"END VERI 0", result_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_opt_result = result_str[begin_idx[i] : end_idx[i]]
            if "Error" in current_opt_result:
                ori_result = "Error"
            else:
                ori_result = current_opt_result

        # Grab all the LIKELY results.
        likely_result = ""
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"BEGIN VERI 1", result_str):
            begin_idx.append(m.end())
        for m in re.finditer(r"END VERI 1", result_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_unopt_result = result_str[begin_idx[i] : end_idx[i]]
            if "Error" in current_unopt_result:
                likely_result = "Error"
            else:
                likely_result = current_unopt_result

        # Grab all the UNLIKELY results.
        unlikely_result = ""
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"BEGIN VERI 2", result_str):
            begin_idx.append(m.end())
        for m in re.finditer(r"END VERI 2", result_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_unopt_result = result_str[begin_idx[i] : end_idx[i]]
            if "Error" in current_unopt_result:
                unlikely_result = "Error"
            else:
                unlikely_result = current_unopt_result

        return [ori_result, likely_result, unlikely_result], RESULT.PASS


    @classmethod
    def comp_query_res(cls, queries_l, all_res_str_l):
        queries = queries_l[0]
        valid_type = cls._get_valid_type_list(queries)

        # Has only one run through
        all_res_str_l = all_res_str_l[0]

        all_res_out = []
        final_res = RESULT.PASS

        # print(opt_result)
        # if idx >= len(opt_result) or idx >= len(unopt_result):
        #     break
        if valid_type == VALID_TYPE_LIKELY.NORM:
            curr_res = cls._check_result_norm(
                all_res_str_l[0], all_res_str_l[1], all_res_str_l[2]
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_LIKELY.DISTINCT:
            curr_res = cls._check_result_norm(
                all_res_str_l[0], all_res_str_l[1], all_res_str_l[2]
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_LIKELY.GROUP_BY:
            curr_res = cls._check_result_norm(
                all_res_str_l[0], all_res_str_l[1], all_res_str_l[2]
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_LIKELY.AVG:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], all_res_str_l[2], valid_type
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_LIKELY.COUNT:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], all_res_str_l[2], valid_type
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_LIKELY.MAX:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], all_res_str_l[2], valid_type
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_LIKELY.MIN:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], all_res_str_l[2], valid_type
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_LIKELY.SUM:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], all_res_str_l[2], valid_type
            )
            all_res_out.append(curr_res)
        else:
            curr_res = RESULT.ERROR
            all_res_out.append(curr_res)

        if all_res_out[0] == RESULT.ERROR:
            return RESULT.ALL_ERROR, all_res_out
        else:
            tmp_res = all_res_out[0]
            return tmp_res, all_res_out

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
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"SELECT 'BEGIN VERI 0';", query):
            begin_idx.append(m.end())
        for m in re.finditer(
            r"SELECT 'END VERI 0';", query
        ):  # Might contains additional unnecessary characters, such as SELECT in the SELECT 97531;
            end_idx.append(m.start())

        current_opt_query = query[begin_idx[0] : end_idx[0]]
        return cls._get_valid_type(current_opt_query)


    @classmethod
    def _get_valid_type(cls, query: str):
        if re.match(
            r"""^[\s;]*SELECT\s*(DISTINCT\s*)(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning valid_type: DISTINCT" % (query.strip()))
            return VALID_TYPE_LIKELY.DISTINCT
        if re.match(
            r"""^[\s;]*SELECT\s*(.+)(GROUP\s*)(BY\s*)(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning valid_type: GROUP_BY" % (query.strip()))
            return VALID_TYPE_LIKELY.GROUP_BY
        elif re.match(
            r"""^[\s;]*SELECT\s*MIN(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning valid_type: MIN" % (query.strip()))
            return VALID_TYPE_LIKELY.MIN
        elif re.match(
            r"""^[\s;]*SELECT\s*MAX(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_LIKELY: MAX" % (query.strip()))
            return VALID_TYPE_LIKELY.MAX
        elif re.match(
            r"""^[\s;]*SELECT\s*SUM(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_LIKELY: SUM" % (query.strip()))
            return VALID_TYPE_LIKELY.SUM
        elif re.match(
            r"""^[\s;]*SELECT\s*AVG(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_LIKELY: AVG" % (query.strip()))
            return VALID_TYPE_LIKELY.AVG
        elif re.match(
            r"""^[\s;]*SELECT\s*COUNT(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_LIKELY: COUNT" % (query.strip()))
            return VALID_TYPE_LIKELY.COUNT
        else:
            # print("For query: %s, returning VALID_TYPE_LIKELY: NORM" % (query.strip()))
            return VALID_TYPE_LIKELY.NORM

    @classmethod
    def _check_result_norm(cls, ori: str, likely: str, unlikely: str) -> RESULT:
        if "Error" in ori or "Error" in likely or "Error" in unlikely:
            return RESULT.ERROR

        ori_out_int = 0
        likely_out_int = 0
        unlikely_out_int = 0

        ori_list = ori.split("\n")
        likely_list = likely.split("\n")
        unlikely_list = unlikely.split("\n")

        for cur_ori in ori_list:
            if re.match(
                r"""^[\|\s]*$""", cur_ori, re.MULTILINE | re.IGNORECASE
            ):  # Only spaces or | (separator)
                continue
            ori_out_int += 1
        for cur_likely in likely_list:
            if re.match(
                r"""^[\|\s]*$""", cur_likely, re.MULTILINE | re.IGNORECASE
            ):  # Only spaces or | (separator)
                continue
            likely_out_int += 1
        for cur_unlikely in unlikely_list:
            if re.match(
                r"""^[\|\s]*$""", cur_unlikely, re.MULTILINE | re.IGNORECASE
            ):  # Only spaces or | (separator)
                continue
            unlikely_out_int += 1

        if ori_out_int != likely_out_int or ori_out_int != unlikely_out_int:
            return RESULT.FAIL
        else:
            return RESULT.PASS
    
    @classmethod
    def _check_result_aggr(cls, ori, likely, unlikely, valid_type) -> RESULT:
        if "Error" in ori or "Error" in likely or "Error" in unlikely:
            return RESULT.ERROR

        ori_out_int: int = 0
        likely_out_int: int = 0
        unlikely_out_int: int = 0
        if valid_type == VALID_TYPE_LIKELY.MAX:
            ori_out_int = 0
            likely_out_int = 0
            unlikely_out_int = 0
        elif valid_type == VALID_TYPE_LIKELY.MIN:
            ori_out_int = maxsize
            likely_out_int = maxsize
        elif valid_type == VALID_TYPE_LIKELY.AVG:
            ori_out_int = 0
            likely_out_int = 0
            unlikely_out_int = 0
        elif valid_type == VALID_TYPE_LIKELY.COUNT or valid_type == VALID_TYPE_LIKELY.SUM:
            ori_out_int = 0
            likely_out_int = 0
            unlikely_out_int = 0
        else:
            raise ValueError(
                "Cannot handle valid_type: "
                + str(valid_type)
                + " in the check_result function. "
            )

        for cur_ori in ori.split("\n"):
            if is_string_only_whitespace(cur_ori):
                continue
            cur_res = 0
            try:
                cur_res = int(cur_ori)
            except ValueError:
                return RESULT.ERROR

            if valid_type == VALID_TYPE_LIKELY.COUNT or valid_type == VALID_TYPE_LIKELY.SUM:
                ori_out_int += cur_res
            elif valid_type == VALID_TYPE_LIKELY.MAX and cur_res > ori_out_int:
                ori_out_int = cur_res
            elif valid_type == VALID_TYPE_LIKELY.MIN and cur_res < ori_out_int:
                ori_out_int = cur_res

        for cur_likely in likely.split("\n"):
            if is_string_only_whitespace(cur_likely):
                continue
            cur_res = 0
            try:
                cur_res = int(cur_likely)
            except ValueError:
                return RESULT.ERROR

            if valid_type == VALID_TYPE_LIKELY.COUNT or valid_type == VALID_TYPE_LIKELY.SUM:
                likely_out_int += cur_res
            elif valid_type == VALID_TYPE_LIKELY.MAX and cur_res > likely_out_int:
                likely_out_int = cur_res
            elif valid_type == VALID_TYPE_LIKELY.MIN and cur_res < likely_out_int:
                likely_out_int = cur_res

        
        for cur_unlikely in unlikely.split("\n"):
            if is_string_only_whitespace(cur_unlikely):
                continue
            cur_res = 0
            try:
                cur_res = int(cur_unlikely)
            except ValueError:
                return RESULT.ERROR

            if valid_type == VALID_TYPE_LIKELY.COUNT or valid_type == VALID_TYPE_LIKELY.SUM:
                unlikely_out_int += cur_res
            elif valid_type == VALID_TYPE_LIKELY.MAX and cur_res > unlikely_out_int:
                unlikely_out_int = cur_res
            elif valid_type == VALID_TYPE_LIKELY.MIN and cur_res < unlikely_out_int:
                unlikely_out_int = cur_res

        if ori_out_int != likely_out_int or ori_out_int != unlikely_out_int:
            # print("UNIQUE Mismatched: opt: %s\n unopt: %s\n opt(int): %d, unopt(int): %d" % (opt, unopt, opt_out_int, unopt_out_int) )
            return RESULT.FAIL
        else:
            return RESULT.PASS
