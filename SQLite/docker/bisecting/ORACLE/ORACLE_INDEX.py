import re
from enum import Enum
from sys import maxsize

from helper.data_struct import RESULT, is_string_only_whitespace


class VALID_TYPE_INDEX(Enum):
    NORM = 1
    MIN = 2
    MAX = 3
    SUM = 4
    COUNT = 5
    AVG = 6
    DISTINCT = 7
    GROUP_BY = 8


class Oracle_INDEX:

    multi_exec_num = 2
    veri_vari_num = 1

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
        # Grab all the results.
        res = ""
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"BEGIN VERI 0", result_str):
            begin_idx.append(m.end())
        for m in re.finditer(r"END VERI 0", result_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_opt_result = result_str[begin_idx[i] : end_idx[i]]
            if "Error" in current_opt_result:
                res ="Error"
            else:
                res = current_opt_result

        return res, RESULT.PASS

    @classmethod
    def comp_query_res(cls, queries_l, all_res_str_l):

        if all_res_str_l[0] == None or all_res_str_l[1] == None:
            return RESULT.SEG_FAULT, None

        # We only need the first query to get the VALID_TYPE_INDEX list.
        queries = queries_l[0]

        valid_type = cls._get_valid_type_list(queries)

        all_res_out = []

        if valid_type == VALID_TYPE_INDEX.NORM:
            curr_res = cls._check_result_norm(
                all_res_str_l[0], all_res_str_l[1]
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_INDEX.DISTINCT:
            curr_res = cls._check_result_norm(
                all_res_str_l[0], all_res_str_l[1]
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_INDEX.GROUP_BY:
            curr_res = cls._check_result_norm(
                all_res_str_l[0], all_res_str_l[1]
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_INDEX.AVG:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], valid_type
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_INDEX.COUNT:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], valid_type
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_INDEX.MAX:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], valid_type
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_INDEX.MIN:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], valid_type
            )
            all_res_out.append(curr_res)
        elif valid_type == VALID_TYPE_INDEX.SUM:
            curr_res = cls._check_result_aggr(
                all_res_str_l[0], all_res_str_l[1], valid_type
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
            return VALID_TYPE_INDEX.DISTINCT
        if re.match(
            r"""^[\s;]*SELECT\s*(.+)(GROUP\s*)(BY\s*)(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning valid_type: GROUP_BY" % (query.strip()))
            return VALID_TYPE_INDEX.GROUP_BY
        elif re.match(
            r"""^[\s;]*SELECT\s*MIN(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning valid_type: MIN" % (query.strip()))
            return VALID_TYPE_INDEX.MIN
        elif re.match(
            r"""^[\s;]*SELECT\s*MAX(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_INDEX: MAX" % (query.strip()))
            return VALID_TYPE_INDEX.MAX
        elif re.match(
            r"""^[\s;]*SELECT\s*SUM(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_INDEX: SUM" % (query.strip()))
            return VALID_TYPE_INDEX.SUM
        elif re.match(
            r"""^[\s;]*SELECT\s*AVG(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_INDEX: AVG" % (query.strip()))
            return VALID_TYPE_INDEX.AVG
        elif re.match(
            r"""^[\s;]*SELECT\s*COUNT(.*?)$""", query, re.IGNORECASE
        ):
            # print("For query: %s, returning VALID_TYPE_INDEX: COUNT" % (query.strip()))
            return VALID_TYPE_INDEX.COUNT
        else:
            # print("For query: %s, returning VALID_TYPE_INDEX: NORM" % (query.strip()))
            return VALID_TYPE_INDEX.NORM

    # The same as Oracle TLP.
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

    # @classmethod
    # def _check_result_uniq(cls, opt, unopt, valid_type) -> RESULT:
    #     if "Error" in opt or "Error" in unopt:
    #         return RESULT.ERROR
    #     if opt != unopt:
    #         return RESULT.FAIL
    #     else:
    #         return RESULT.PASS

    @classmethod
    def _check_result_aggr(cls, opt, unopt, valid_type) -> RESULT:
        if "Error" in opt or "Error" in unopt:
            return RESULT.ERROR

        opt_out_int: int = 0
        unopt_out_int: int = 0
        if valid_type == VALID_TYPE_INDEX.MAX:
            opt_out_int = 0
            unopt_out_int = 0
        elif valid_type == VALID_TYPE_INDEX.MIN:
            opt_out_int = maxsize
            unopt_out_int = maxsize
        elif valid_type == VALID_TYPE_INDEX.AVG:
            opt_out_int = 0
            unopt_out_int = 0
        elif valid_type == VALID_TYPE_INDEX.COUNT or valid_type == VALID_TYPE_INDEX.SUM:
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

            if valid_type == VALID_TYPE_INDEX.COUNT or valid_type == VALID_TYPE_INDEX.SUM:
                opt_out_int += cur_res
            elif valid_type == VALID_TYPE_INDEX.MAX and cur_res > opt_out_int:
                opt_out_int = cur_res
            elif valid_type == VALID_TYPE_INDEX.MIN and cur_res < opt_out_int:
                opt_out_int = cur_res

        for cur_unopt in unopt.split("\n"):
            if is_string_only_whitespace(cur_unopt):
                continue
            cur_res = 0
            try:
                cur_res = int(cur_unopt)
            except ValueError:
                return RESULT.ERROR

            if valid_type == VALID_TYPE_INDEX.COUNT or valid_type == VALID_TYPE_INDEX.SUM:
                unopt_out_int += cur_res
            elif valid_type == VALID_TYPE_INDEX.MAX and cur_res > unopt_out_int:
                unopt_out_int = cur_res
            elif valid_type == VALID_TYPE_INDEX.MIN and cur_res < unopt_out_int:
                unopt_out_int = cur_res

        if opt_out_int != unopt_out_int:
            # print("UNIQUE Mismatched: opt: %s\n unopt: %s\n opt(int): %d, unopt(int): %d" % (opt, unopt, opt_out_int, unopt_out_int) )
            return RESULT.FAIL
        else:
            return RESULT.PASS
