from typing import List, Tuple

import constants
from loguru import logger


class Oracle_TLP:

    @staticmethod
    def is_aggregate_func(query_str: str):
        for cur_line in query_str.splitlines():
            if "where" in cur_line.casefold() and "select" in cur_line.casefold() and "from" in cur_line.casefold():
                # This is a SELECT statement. 
                if "max" in cur_line.casefold() or "min" in cur_line.casefold() \
                        or "sum" in cur_line.casefold() or "count" in cur_line.casefold() \
                        or "avg" in cur_line.casefold():
                            logger.debug("Aggregate function. ")
                            return True

        logger.debug("Aggregate function. ")
        return False

    @staticmethod
    def comp_query_res(all_res_lll, query_str: str) -> Tuple[constants.RESULT, List[constants.RESULT]]:
        # Has only one run through
        all_res_ll = all_res_lll[0]

        is_aggregate = Oracle_TLP.is_aggregate_func(query_str)

        all_res_out = []
        for cur_res_l in all_res_ll:
            opt_l = cur_res_l[0]
            unopt_l = cur_res_l[1]

            opt_int_l = []
            unopt_int_l = []
            if not is_aggregate:
                opt_int_l.append(len(opt_l))
                unopt_int_l.append(len(unopt_l))
            else:
                # aggregate function, directly use the str to int cast. 
                try:
                    opt_int_l = list(map(lambda n: int(float(n)), opt_l))
                    unopt_int_l = list(map(lambda n: int(float(n)), unopt_l))
                except (ValueError, TypeError):
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
