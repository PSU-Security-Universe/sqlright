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
                opt_results.append(-1)
            else:
                try:
                    current_opt_result_int = int(current_opt_result)
                except ValueError:
                    current_opt_result_int = -1
                opt_results.append(current_opt_result_int)

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
                unopt_results.append(-1)
            else:
                try:
                    current_unopt_result_int = int(
                        float(current_unopt_result) + 0.0001
                    )  # Add 0.0001 to avoid inaccurate float to int transform. Transform are towards 0.
                except ValueError:
                    current_unopt_result_int = -1
                unopt_results.append(current_unopt_result_int)

        all_results_out = []
        for i in range(min(len(opt_results), len(unopt_results))):
            cur_results_out = [opt_results[i], unopt_results[i]]
            all_results_out.append(cur_results_out)

        return all_results_out, RESULT.PASS

    @classmethod
    def comp_query_res(cls, queries_l, all_res_str_l):
        # Has only one run through
        all_res_str_l = all_res_str_l[0]

        all_res_out = []
        final_res = RESULT.PASS

        for cur_res_str_l in all_res_str_l:
            opt_int = cur_res_str_l[0]
            unopt_int = cur_res_str_l[1]

            if opt_int == -1 or unopt_int == -1:
                all_res_out.append(RESULT.ERROR)
            elif opt_int != unopt_int:
                all_res_out.append(RESULT.FAIL)
            else:
                all_res_out.append(RESULT.PASS)

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
