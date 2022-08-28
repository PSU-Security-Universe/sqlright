import re

from helper.data_struct import RESULT, is_string_only_whitespace

class Oracle_OPT:

    multi_exec_num = 3
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

        # Grab all the opt results.
        res = ""
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"BEGIN VERI 0", result_str):
            begin_idx.append(m.end())
        for m in re.finditer(r"END VERI 0", result_str):
            end_idx.append(m.start())

        res = result_str[begin_idx[0] : end_idx[0]]
        if "Error" in res:
            return (res, RESULT.ALL_ERROR)

        return res, RESULT.PASS

    @classmethod
    def comp_query_res(cls, queries_l, all_res_str_l):

        if len(all_res_str_l) < 3:
            print("all_res_int_l does not have length 3. \n")
            return RESULT.ALL_ERROR, None

        # print("Comparing string 1: \n%s\nstring 2:\n%s\nstring 3:\n%s\n" % (all_res_str_l[-3], all_res_str_l[-2], all_res_str_l[-1]))

        first_res = all_res_str_l[0]
        for other_res in all_res_str_l:
            if first_res != other_res:
                return RESULT.FAIL, [RESULT.FAIL]
        return RESULT.PASS, [RESULT.PASS]
