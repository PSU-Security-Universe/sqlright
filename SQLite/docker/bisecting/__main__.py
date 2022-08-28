import sys
import os
import time
from git import Repo
import getopt

sys.path.append(os.getcwd())

from bi_config import *
from helper import VerCon, IO, log_out_line, Bisect
from ORACLE import Oracle_TLP, Oracle_NOREC, Oracle_ROWID, Oracle_INDEX, Oracle_LIKELY, Oracle_OPT

def main():

    IO.gen_unique_bug_output_dir()

    oracle_str = ""

    is_non_deter = False

    try:

        opts, args = getopt.getopt(sys.argv[1:], "O:F:", ["oracle=", "feedback=", "non-deter"])

    except getopt.GetoptError:
        print("Arguments parsing error")
        exit(1)
    for opt, arg in opts:
        if opt in ("-O", "--oracle"):
            oracle_str = arg
            print("Using oracle: %s " % (oracle_str))
        elif opt in ("-F", "--feedback"):
            # Ignored. 
            pass
        elif opt in ("--non-deter"):
            is_non_deter = True
            print("Using non-deterministic queries. ")
        else:
            print("Error. Input arguments not supported. \n")
            exit(1)

    oracle = 0
    if oracle_str == "NOREC":
        oracle = Oracle_NOREC
    elif oracle_str == "TLP":
        oracle = Oracle_TLP
    elif oracle_str == "OPT":
        oracle = Oracle_OPT
    else:
        oracle = Oracle_OPT


    sys.stdout.flush()
    fuzzing_start_time = 0

    # all_existed_commits_l.clear()
    # Fuzzer.setup_and_run_fuzzing(oracle_str)

    repo = Repo(SQLITE_DIR)
    assert not repo.bare

    vercon = VerCon()
    all_commits_hexsha, all_tags = vercon.get_all_commits(repo=repo)
    log_out_line(
        "Getting %d number of commits, and %d number of tags. \n\n"
        % (len(all_commits_hexsha), len(all_tags))
    )

    log_out_line(
        "Begins processing bug reports in the target folder. "
    )
    while True:
        # Read one file at a time.
        # all_new_queries is a two layer list. Selects and then different runs. 
        # The reason we set different select as the first layer, is because
        # different select mismatches could be caused by different reasons. 
        # But different runs for the same select should always be the same bug. 
        all_new_queries, current_file_d = IO.read_queries_from_files(
            file_directory=BUG_SAMPLE_DIR, 
            is_removed_read=False
        )
        if all_new_queries == None or current_file_d == "Done":
            print("Done")
            break
        elif all_new_queries == []:
            time.sleep(1.0)
            continue

        """ Every cur_new_queries is a pair of oracle statement. 
            If the oracle contains different query sequence runs, then it would 
            have multiple cur_run_queries. 

            Here, we are iterating SELECT oracle pairs. If the afl-fuzz uses 100 SELECT
            statement pairs, here we will have 100 iterations. 
        """
        is_skip = False

        for cur_select_queries in all_new_queries:
            for cur_new_queries in cur_select_queries:
                if is_skip:
                    break
                # Early drop the query if the query contains `rtree`, if is_non_deter is not set.
                if len(cur_new_queries) > 0 and "rtree" in cur_new_queries[0].casefold() and not is_non_deter:
                    is_dup_commit = True
                    is_skip = True
                    break

        if is_skip:
            print("Early drop the file %s, because it contains non-deter behaviors. " % (current_file_d))
            continue

        for cur_select_queries in all_new_queries:
            is_dup_commit = False

            cur_is_dup_commit = Bisect.run_bisecting(
                queries_l=cur_select_queries,
                oracle=oracle,
                vercon=vercon,
                current_file=current_file_d,
                is_non_deter = is_non_deter
            )
            if cur_is_dup_commit:
                is_dup_commit = True

            if not is_dup_commit:
                cur_bug_time = os.path.getmtime(os.path.join(BUG_SAMPLE_DIR, current_file_d))
                duration = 0
                if fuzzing_start_time == 0:
                    fuzzing_start_time = cur_bug_time
                    duration = 0
                else:
                    duration = cur_bug_time - fuzzing_start_time

                with open(os.path.join(UNIQUE_BUG_OUTPUT_DIR, "time.txt"), "a") as f:
                    f.write(
                        "{} {}\n".format(
                            os.path.basename(current_file_d), duration
                        )
                    )

        IO.status_print()


if __name__ == "__main__":
    main()
