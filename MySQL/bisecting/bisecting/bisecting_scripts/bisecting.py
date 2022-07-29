from typing import List, Tuple
import mysql
import constants
from ORACLE import Oracle_NoREC
from ORACLE import Oracle_TLP
import reports
import utils
from loguru import logger
import os

uniq_bug_id_int = 0
all_unique_results_dict = dict()
all_previous_compile_failure = []


def check_query_execute_correctness(queries_l: List[str], hexsha: str, oracle_str: str):
    install_directory = os.path.join(constants.MYSQL_ROOT, hexsha)

#    cur_mysqld_binary_dir = os.path.join(install_directory, "bin/mysqld")
#    if not os.path.isfile(cur_mysqld_binary_dir):
#        logger.warning("Cannot find MySQL version %s in the install_directory: %s" % (hexsha, install_directory))
#        return constants.RESULT.SEG_FAULT, [], []
    
    mysql.start_mysqld_server(hexsha)

    all_res_str_l: List[str] = []
    for queries in queries_l:
        all_res_str, result = mysql.execute_queries(queries, hexsha)
        all_res_str_l.append(all_res_str)

    if result == constants.RESULT.SEG_FAULT:
        logger.debug("Commit Segmentation fault. \n")
        return constants.RESULT.SEG_FAULT, [], []

    if not all_res_str_l or result == constants.RESULT.ALL_ERROR:
        logger.debug("Result all Errors. \n")
        return constants.RESULT.ALL_ERROR, [], []

    final_flag = constants.RESULT.PASS
    all_res_flags = []
    if oracle_str == "NOREC" or oracle_str == "NoREC":
        logger.debug("Using Oracle NoREC")
        final_flag, all_res_flags = Oracle_NoREC.comp_query_res(all_res_str_l)
    elif oracle_str == "TLP":
        logger.debug("Using Oracle TLP")
        final_flag, all_res_flags = Oracle_TLP.comp_query_res(all_res_str_l, queries_l[0])
    else:
        logger.error("Oracle_str: %s not recognized. Using the default NOREC oracle instead. ")
        final_flag, all_res_flags = Oracle_NoREC.comp_query_res(all_res_str_l)


    return final_flag, all_res_flags, all_res_str_l


def cross_compare(buggy_commit: str):
    global uniq_bug_id_int
    global all_unique_results_dict

    def get_valid_uniq_id():
        return (
            max(v for v in all_unique_results_dict.values()) + 1
            if all_unique_results_dict
            else 0
        )

    is_unique_commit = False
    if buggy_commit in all_unique_results_dict:
        return all_unique_results_dict[buggy_commit], is_unique_commit

    is_unique_commit = True
    uniq_id = get_valid_uniq_id()
    all_unique_results_dict[buggy_commit] = uniq_id

    return uniq_id, is_unique_commit


def start_bisect(queries: List[str], all_commits, oracle_str: str, is_non_deter: bool):
    current_bisecting_result = bi_secting_commits(queries, all_commits, oracle_str)
    if current_bisecting_result.is_bisecting_error:
        logger.error("Bisecting Error!")
        return False

    # The unique bug id will be appended to current_bisecting_result when running cross_compare
    buggy_commit = current_bisecting_result.first_buggy_commit_id
    uniq_id, is_unique_commit = cross_compare(buggy_commit)
    current_bisecting_result.unique_bug_id_int = uniq_id

    if is_unique_commit:
        is_unique_commit = reports.dump_unique_bugs(current_bisecting_result, is_non_deter)

    return is_unique_commit

def bi_secting_commits(queries: List[str], all_commits_str, oracle_str:str):
    # The oldest buggy commit, which is the commit that introduce the bug.
    newer_commit_str = all_commits_str[0]  # The latest buggy commit.
    older_commit_str = all_commits_str[-1]  # The oldest correct commit.
    newer_commit_index = 0
    older_commit_index = len(all_commits_str)-1
    last_buggy_res_l = None
    last_buggy_all_result_flags = None
    is_error_returned_from_exec = False
    current_commit_str = ""

    rn_correctness = constants.RESULT.PASS

    current_bisecting_result = constants.BisectingResults()

    is_buggy_commit_found = False

    logger.debug("Bisecting on pre-compiled binaries. \n")

    while not is_buggy_commit_found:
        if abs(newer_commit_index - older_commit_index) <= 1:
            logger.debug(
                f"found buggy_commit: {newer_commit_index} : {older_commit_index}"
            )
            is_buggy_commit_found = True
            break

        # Approximate towards 0 (older).
        tmp_commit_index = int((newer_commit_index + older_commit_index) / 2)

        is_successfully_executed = False
        while not is_successfully_executed:
            commit_ID = all_commits_str[tmp_commit_index]

            (
                rn_correctness,
                all_res_flags,
                all_res_str_l,
            ) = check_query_execute_correctness(queries, commit_ID, oracle_str)
            if rn_correctness == constants.RESULT.PASS:  # The correct version.
                older_commit_index = tmp_commit_index
                is_successfully_executed = True
                logger.debug(f"For commit {commit_ID}. Bisecting Pass. \n")
                break
            elif rn_correctness == constants.RESULT.FAIL:  # The buggy version.
                newer_commit_index = tmp_commit_index
                is_successfully_executed = True
                if all_res_str_l != None:
                    last_buggy_res_l = all_res_str_l
                last_buggy_all_result_flags = all_res_flags
                logger.debug(f"For commit {commit_ID}. Bisecting Buggy. \n")
                break
            elif rn_correctness == constants.RESULT.ERROR:
                older_commit_index = tmp_commit_index
                is_successfully_executed = True
                is_error_returned_from_exec = True
                logger.debug(f"For commit {commit_ID}. Bisecting ERROR. \n")
                break
            elif rn_correctness == constants.RESULT.FAIL_TO_COMPILE:
                newer_commit_index = tmp_commit_index
                is_successfully_executed = False
                is_error_returned_from_exec = True

                logger.debug(f"For commit {commit_ID}. Bisecting FAIL_TO_COMPILE. \n")
                utils.dump_failed_commit(commit_ID)
                break
            else:
                older_commit_index = tmp_commit_index
                is_successfully_executed = False
                is_error_returned_from_exec = True
                logger.debug(
                    f"For commit {commit_ID}, Bisecting Segmentation Fault. \n"
                )
                break

    if is_buggy_commit_found:
        logger.info(
            "Found the bug introduced commit: %s \n\n\n"
            % (all_commits_str[newer_commit_index])
        )
        logger.info(
            f"Found the correct commit: {all_commits_str[older_commit_index]} \n\n\n"
        )

        current_bisecting_result.query = queries
        current_bisecting_result.first_buggy_commit_id = all_commits_str[
            newer_commit_index
        ]
        current_bisecting_result.first_corr_commit_id = all_commits_str[
            older_commit_index
        ]
        current_bisecting_result.is_error_returned_from_exec = (
            is_error_returned_from_exec
        )
        current_bisecting_result.is_bisecting_error = False
        current_bisecting_result.last_buggy_res_str_l = last_buggy_res_l
        # logger.debug("All_res_str_l: " + str(current_bisecting_result.last_buggy_res_str_l) + "\n")
        current_bisecting_result.last_buggy_res_flags_l = last_buggy_all_result_flags
        # logger.debug("All_res_flags: " + str(current_bisecting_result.last_buggy_res_flags_l) + "\n")
        current_bisecting_result.final_res_flag = rn_correctness

        return current_bisecting_result
    else:
        Error_reason = "Error: Returning is_buggy_commit_found == False. Possibly related to compilation failure. \n\n\n"
        logger.debug(Error_reason)

        current_bisecting_result.query = queries
        current_bisecting_result.is_error_returned_from_exec = (
            is_error_returned_from_exec
        )
        current_bisecting_result.is_bisecting_error = True
        current_bisecting_result.bisecting_error_reason = Error_reason
        current_bisecting_result.last_buggy_res_str_l = last_buggy_res_l
        current_bisecting_result.last_buggy_res_flags_l = last_buggy_all_result_flags
        current_bisecting_result.final_res_flag = rn_correctness

        return current_bisecting_result
