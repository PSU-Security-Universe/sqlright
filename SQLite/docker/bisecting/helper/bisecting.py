import os
from helper.version_control import VerCon
from helper.data_struct import BisectingResults, RESULT, log_out_line
from helper.executor import Executor
from helper.io import IO
from bi_config import UNIQUE_BUG_OUTPUT_DIR, CUR_WORKDIR


class Bisect:

    uniq_bug_id_int = 0
    all_unique_results_dict = dict()
    all_previous_compile_failure = []

    @staticmethod
    def _check_query_exec_correctness_under_commitID(queries_l, commit_ID: str, oracle):
        INSTALL_DEST_DIR = VerCon.setup_SQLITE_with_commit(hexsha=commit_ID)

        if INSTALL_DEST_DIR == "":
            log_out_line("Commit failed to compile. \n")
            return RESULT.FAIL_TO_COMPILE, None, None  # Failed to compile commit.

        all_res_str_l = []
        for queries in queries_l:
            all_res_str, res = Executor.execute_queries(
                queries=queries, sqlite_install_dir=INSTALL_DEST_DIR, oracle=oracle
            )
            all_res_str_l.append(all_res_str)

        if res == RESULT.SEG_FAULT:
            log_out_line("Commit Segmentation fault. \n")
            return RESULT.SEG_FAULT, None, None

        if len(all_res_str_l) == 0 or res == RESULT.ALL_ERROR:
            log_out_line("Result all Errors. \n")
            return RESULT.ALL_ERROR, None, None

        final_flag, all_res_flags = oracle.comp_query_res(queries_l, all_res_str_l)

        #log_out_line("All_res_str_l: " + str(all_res_str_l) + "\n")
        #log_out_line("Result with final_flag: " + str(final_flag))
        return final_flag, all_res_flags, all_res_str_l

    @classmethod
    def setup_previous_compile_fail(cls):
        fail_compiled_commits_file = os.path.join(CUR_WORKDIR, "fail_compiled_commits.txt")
        if os.path.exists(fail_compiled_commits_file):
            with open(fail_compiled_commits_file, "r") as f:
                cls.all_previous_compile_failure = [
                    commit.strip() for commit in f.readlines()
                ]
        else:
            # Create the file. Don't write anything. 
            with open(fail_compiled_commits_file, 'w') as fp:
                pass

    @classmethod
    def bi_secting_commits(
        cls, queries_l, oracle, vercon
    ):  # Returns Bug introduce commit_ID:str, is_error_result:bool
        all_commits_str = vercon.all_commits_hexsha
        all_tags = vercon.all_tags
        # The oldest buggy commit, which is the commit that introduce the bug.
        newer_commit_str = ""
        older_commit_str = ""  # The latest correct commit.
        last_buggy_res_l = None
        last_buggy_all_result_flags = None
        is_error_returned_from_exec = False
        current_commit_str = ""

        cls.setup_previous_compile_fail()

        rn_correctness = RESULT.PASS

        current_bisecting_result = BisectingResults()

        log_out_line("Bisecting main releases: \n")

        for current_tag in reversed(
            all_tags
        ):  # From the latest tag to the earliest tag.
            current_commit_str = current_tag.commit.hexsha
            current_commit_index = all_commits_str.index(current_commit_str)
            is_successfully_executed = False
            is_commit_found = False

            while not is_successfully_executed:
                current_commit_str = all_commits_str[current_commit_index]
                if current_commit_str in cls.all_previous_compile_failure:
                    rn_correctness = RESULT.FAIL_TO_COMPILE
                    # log_out_line("For commit %s. Bisecting FAIL_TO_COMPILE. \n" % (commit_ID))

                else:
                    (
                        rn_correctness,
                        all_res_flags,
                        all_res_str_l,
                    ) = cls._check_query_exec_correctness_under_commitID(
                        queries_l=queries_l, commit_ID=current_commit_str, oracle=oracle
                    )
                if rn_correctness == RESULT.PASS:  # Execution result is correct.
                    older_commit_str = current_commit_str
                    is_successfully_executed = True
                    is_commit_found = True
                    log_out_line("For commit %s. Bisecting Pass. \n" % (current_commit_str))
                    break
                elif rn_correctness == RESULT.FAIL:  # Execution result is buggy
                    newer_commit_str = current_commit_str
                    is_successfully_executed = True
                    if all_res_str_l != None:
                        last_buggy_res_l = all_res_str_l
                    last_buggy_all_result_flags = all_res_flags
                    log_out_line("For commit %s. Bisecting Buggy. \n" % (current_commit_str))
                    break
                elif (
                    rn_correctness == RESULT.ALL_ERROR
                ):  # Execution queries all return errors. Treat it similar to execution result is correct.
                    older_commit_str = current_commit_str
                    is_successfully_executed = True
                    is_commit_found = True
                    is_error_returned_from_exec = True
                    log_out_line("For commit %s. Bisecting ALL_ERROR. \n" % (current_commit_str))
                    break
                elif rn_correctness == RESULT.FAIL_TO_COMPILE:
                    newer_commit_str = current_commit_str
                    is_successfully_executed = False
                    is_commit_found = False
                    log_out_line("For commit %s, Bisecting FAIL_TO_COMPILE. \n" % (current_commit_str))

                    if current_commit_str in cls.all_previous_compile_failure:
                        break
                    cls.all_previous_compile_failure.append(current_commit_str)


                    fail_compiled_commits_file = os.path.join(
                        CUR_WORKDIR, "fail_compiled_commits.txt"
                    )

                    with open(fail_compiled_commits_file, "a") as f:
                        f.write(current_commit_str + "\n")

                    break
                else:  
                    older_commit_str = current_commit_str
                    is_successfully_executed = False
                    is_commit_found = False
                    is_error_returned_from_exec = True
                    log_out_line("For commit %s, Bisecting Segmentation Fault. \n" % (current_commit_str))
                    break
            if is_commit_found:
                break

        if newer_commit_str == "":
            # Error_reason = "Error: The latest commit: %s already fix this bug, or the latest commit is returnning errors!!! \nOpt: \"%s\", \nunopt: \"%s\". \nReturning None. \n" % (older_commit_str, opt_unopt_queries[0], opt_unopt_queries[1])
            Error_reason = (
                "Error: The latest commit: %s already fix this bug, or the latest commit is returnning errors!!!\n\n\n"
                % (current_commit_str)
            )
            log_out_line(Error_reason)

            current_bisecting_result.query = queries_l
            current_bisecting_result.first_corr_commit_id = current_commit_str
            current_bisecting_result.is_error_returned_from_exec = (
                is_error_returned_from_exec
            )
            current_bisecting_result.is_bisecting_error = True
            current_bisecting_result.bisecting_error_reason = Error_reason
            current_bisecting_result.last_buggy_res_str_l = last_buggy_res_l
            current_bisecting_result.last_buggy_res_flags_l = (
                last_buggy_all_result_flags
            )
            current_bisecting_result.final_res_flag = rn_correctness

            return current_bisecting_result

        if older_commit_str == "":
            Error_reason = "Error: Cannot find the bug introduced commit (already iterating to the earliest version)!!!\n\n\n"
            log_out_line(Error_reason)

            current_bisecting_result.query = queries_l
            current_bisecting_result.is_error_returned_from_exec = (
                is_error_returned_from_exec
            )
            current_bisecting_result.is_bisecting_error = True
            current_bisecting_result.bisecting_error_reason = Error_reason
            current_bisecting_result.last_buggy_res_str_l = last_buggy_res_l
            current_bisecting_result.last_buggy_res_flags_l = (
                last_buggy_all_result_flags
            )
            current_bisecting_result.final_res_flag = rn_correctness

            return current_bisecting_result

        newer_commit_index = all_commits_str.index(newer_commit_str)
        older_commit_index = all_commits_str.index(older_commit_str)

        is_buggy_commit_found = False

        log_out_line("Bisecting between two main releases. \n")

        while not is_buggy_commit_found:
            if (newer_commit_index - older_commit_index) <= 1:
                is_buggy_commit_found = True
                break
            tmp_commit_index = int(
                (newer_commit_index + older_commit_index) / 2
            )  # Approximate towards 0 (older).

            is_successfully_executed = False
            while not is_successfully_executed:
                commit_ID = all_commits_str[tmp_commit_index]
                if commit_ID in cls.all_previous_compile_failure:
                    rn_correctness = RESULT.FAIL_TO_COMPILE

                else:
                    (
                        rn_correctness,
                        all_res_flags,
                        all_res_str_l,
                    ) = cls._check_query_exec_correctness_under_commitID(
                        queries_l=queries_l, commit_ID=commit_ID, oracle=oracle
                    )
                if rn_correctness == RESULT.PASS:  # The correct version.
                    older_commit_index = tmp_commit_index
                    is_successfully_executed = True
                    log_out_line("For commit %s. Bisecting Pass. \n" % (commit_ID))
                    break
                elif rn_correctness == RESULT.FAIL:  # The buggy version.
                    newer_commit_index = tmp_commit_index
                    is_successfully_executed = True
                    if all_res_str_l != None:
                        last_buggy_res_l = all_res_str_l
                    last_buggy_all_result_flags = all_res_flags
                    log_out_line("For commit %s. Bisecting Buggy. \n" % (commit_ID))
                    break
                elif rn_correctness == RESULT.ERROR:
                    older_commit_index = tmp_commit_index
                    is_successfully_executed = True
                    is_error_returned_from_exec = True
                    log_out_line("For commit %s. Bisecting ERROR. \n" % (commit_ID))
                    break
                elif rn_correctness == RESULT.FAIL_TO_COMPILE:
                    newer_commit_index = tmp_commit_index
                    is_successfully_executed = False
                    is_error_returned_from_exec = True

                    log_out_line("For commit %s. Bisecting FAIL_TO_COMPILE. \n" % (commit_ID))

                    if commit_ID in cls.all_previous_compile_failure:
                        break
                    cls.all_previous_compile_failure.append(commit_ID)

                    fail_compiled_commits_file = os.path.join(
                        CUR_WORKDIR, "fail_compiled_commits.txt"
                    )

                    with open(fail_compiled_commits_file, "a") as f:
                        f.write(commit_ID + "\n")

                    break
                else:  
                    older_commit_index = tmp_commit_index
                    is_successfully_executed = False
                    is_error_returned_from_exec = True
                    log_out_line("For commit %s, Bisecting Segmentation Fault. \n" % (commit_ID))                    
                    break

        if is_buggy_commit_found:
            log_out_line(
                "Found the bug introduced commit: %s \n\n\n"
                % (all_commits_str[newer_commit_index])
            )

            current_bisecting_result.query = queries_l
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
            # log_out_line("All_res_str_l: " + str(current_bisecting_result.last_buggy_res_str_l) + "\n")
            current_bisecting_result.last_buggy_res_flags_l = (
                last_buggy_all_result_flags
            )
            # log_out_line("All_res_flags: " + str(current_bisecting_result.last_buggy_res_flags_l) + "\n")
            current_bisecting_result.final_res_flag = rn_correctness

            return current_bisecting_result
        else:
            Error_reason = "Error: Returnning is_buggy_commit_found == False. Possibly related to compilation failure. \n\n\n"
            log_out_line(Error_reason)

            current_bisecting_result.query = queries_l
            current_bisecting_result.is_error_returned_from_exec = (
                is_error_returned_from_exec
            )
            current_bisecting_result.is_bisecting_error = True
            current_bisecting_result.bisecting_error_reason = Error_reason
            current_bisecting_result.last_buggy_res_str_l = last_buggy_res_l
            current_bisecting_result.last_buggy_res_flags_l = (
                last_buggy_all_result_flags
            )
            current_bisecting_result.final_res_flag = rn_correctness

            return current_bisecting_result

    @classmethod
    def cross_compare(cls, current_bisecting_result):
        current_commit_ID = current_bisecting_result.first_buggy_commit_id
        if current_commit_ID not in cls.all_unique_results_dict:
            cls.all_unique_results_dict[current_commit_ID] = [cls.uniq_bug_id_int, 1]
            current_bisecting_result.uniq_bug_id_int = cls.uniq_bug_id_int
            cls.uniq_bug_id_int += 1
            return current_bisecting_result, False, 1  # Not duplicated results.
        else:
            cls.all_unique_results_dict[current_commit_ID][1] += 1 # dup_count += 1
            current_bug_id_pair = cls.all_unique_results_dict[current_commit_ID]
            current_bisecting_result.uniq_bug_id_int = current_bug_id_pair[0]
            return current_bisecting_result, True, current_bug_id_pair[1]  # Duplicated results. Return duplicated count

    @classmethod
    def run_bisecting(cls, queries_l, oracle, vercon, current_file, iter_idx:int, is_non_deter: bool):
        log_out_line(
            "\n\n\nBegin bisecting query with SELECT idx %d: \n\n%s \n\n\n"
            % (iter_idx, queries_l[0])
        )
        current_bisecting_result = cls.bi_secting_commits(
            queries_l=queries_l, oracle=oracle, vercon=vercon
        )
        is_dup_commit = True
        if not current_bisecting_result.is_bisecting_error:
            current_bisecting_result, is_dup_commit, dup_count = cls.cross_compare(
                current_bisecting_result
            )  # The unique bug id will be appended to current_bisecting_result when running cross_compare

            current_unique_bug_output = IO.write_uniq_bugs_to_files(
                current_bisecting_result, oracle, dup_count, is_non_deter
            )
            
            if current_unique_bug_output == None:
                # return is_dup_commit = True
                return True

            bug_map_path = os.path.join(UNIQUE_BUG_OUTPUT_DIR, "map.txt")
            with open(bug_map_path, "a") as f:
                f.write(
                    "{}: Count {}: {}\n".format(
                        os.path.basename(current_unique_bug_output),
                        dup_count,
                        os.path.basename(current_file),
                    )
                )
        else:
            current_bisecting_result.uniq_bug_id_int = (
                "Unknown"  # Unique bug id is Unknown. Meaning unsorted or unknown bug.
            )
            # IO.write_uniq_bugs_to_files(current_bisecting_result, oracle)
        return is_dup_commit

    @classmethod
    def pure_add_commit(cls, commit_id_l):
        for commit_id in commit_id_l:
            if commit_id != "Unknown":
                cls.all_unique_results_dict[commit_id] = cls.uniq_bug_id_int
                cls.uniq_bug_id_int += 1
