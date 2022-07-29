from typing import List, Tuple

import constants
from loguru import logger


class Oracle_NoREC:

    @staticmethod
    def comp_query_res(all_res_lll) -> Tuple[constants.RESULT, List[constants.RESULT]]:
        # Has only one run through
        all_res_ll = all_res_lll[0]

        all_res_out = []
        for cur_res_l in all_res_ll:
            opt_l = cur_res_l[0]
            unopt_l = cur_res_l[1]

            try:
                opt_int_l = list(map(lambda n: int(n), opt_l))
                unopt_int_l = list(map(lambda n: int(n), unopt_l))
            except ValueError:
                opt_int_l = [-1]
                unopt_int_l = [-1]

            result = constants.RESULT.PASS
            if opt_int_l == [-1] or unopt_int_l == [-1]:
                result = constants.RESULT.ERROR
            elif opt_int_l != unopt_int_l:
                result = constants.RESULT.FAIL

            all_res_out.append(result)

        final_res = constants.RESULT.PASS
        if any(result == constants.RESULT.FAIL for result in all_res_out):
            final_res = constants.RESULT.FAIL
        if all(result == constants.RESULT.ERROR for result in all_res_out):
            final_res = constants.RESULT.ALL_ERROR

        return final_res, all_res_out
