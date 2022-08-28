import re


from helper.data_struct import RESULT, is_string_only_whitespace


class Oracle_NOREC:

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
        opt_result = -1
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"BEGIN VERI 0", result_str):
            begin_idx.append(m.end())
        for m in re.finditer(r"END VERI 0", result_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_opt_result = result_str[begin_idx[i] : end_idx[i]]
            if "Error" in current_opt_result:
                opt_result = -1
            else:
                try:
                    current_opt_result_int = int(current_opt_result)
                except ValueError:
                    current_opt_result_int = -1
                opt_result = current_opt_result_int

        # Grab all the unopt results.
        unopt_result = -1
        begin_idx = []
        end_idx = []
        for m in re.finditer(r"BEGIN VERI 1", result_str):
            begin_idx.append(m.end())
        for m in re.finditer(r"END VERI 1", result_str):
            end_idx.append(m.start())
        for i in range(min(len(begin_idx), len(end_idx))):
            current_unopt_result = result_str[begin_idx[i] : end_idx[i]]
            if "Error" in current_unopt_result:
                unopt_result = -1
            else:
                try:
                    current_unopt_result_int = int(
                        float(current_unopt_result) + 0.0001
                    )  # Add 0.0001 to avoid inaccurate float to int transform. Transform are towards 0.
                except ValueError:
                    current_unopt_result_int = -1
                unopt_result = current_unopt_result_int

        return [opt_result, unopt_result], RESULT.PASS

    @classmethod
    def comp_query_res(cls, queries_l, all_res_str_l):
        # Has only one run through
        all_res_str_l = all_res_str_l[0]

        opt_int = all_res_str_l[0]
        unopt_int = all_res_str_l[1]

        if opt_int == -1 or unopt_int == -1:
            return RESULT.ALL_ERROR, [RESULT.ERROR]
        elif opt_int != unopt_int:
            return RESULT.FAIL, [RESULT.FAIL]
        else:
            return RESULT.PASS, [RESULT.PASS]
