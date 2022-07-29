import bisecting
import click
import constants
import reports
import utils
from loguru import logger
import os
from pathlib import Path
import getopt
import sys

def setup_logger(debug_level):
    logger.add(
        constants.LOG_OUTPUT_FILE,
        format="{time} {level} {message}",
        level=debug_level,
        rotation="100 MB",
    )


def enter_bisecting_mode(oracle_str: str, is_non_deter: bool):

    all_commits = utils.json_load(constants.MYSQL_SORTED_COMMITS)
    logger.info(f"Getting {len(all_commits)} number of commits.")

    logger.info("Beginning processing files in the target folder.")

    fuzzing_start_time = 0

    for sample_file, sample_queries in reports.read_queries_from_files():
        is_unique_commit = True
        for sample_query in sample_queries:
            cur_is_unique_commit = bisecting.start_bisect(sample_query, all_commits, oracle_str, is_non_deter)
            
            if not cur_is_unique_commit:
                is_unique_commit = False

        # Log the sample bug generation time.
        if is_unique_commit == True:
            cur_bug_time = os.path.getmtime(sample_file)
            duration = 0
            # Log the bug output time. 
            if fuzzing_start_time == 0:
                fuzzing_start_time = cur_bug_time
                duration = 0
            else:
                duration = cur_bug_time - fuzzing_start_time

            with open(os.path.join(constants.UNIQUE_BUG_OUTPUT_DIR, "time.txt"), "a") as f:
                f.write(
                    "{} {}\n".format(
                        os.path.basename(sample_file), duration
                    )
                )


def setup_env():
    # remove and re-create the unique bug output directory.
    if os.path.isdir(constants.UNIQUE_BUG_OUTPUT_DIR):
        utils.remove_directory(constants.UNIQUE_BUG_OUTPUT_DIR)
    os.mkdir(constants.UNIQUE_BUG_OUTPUT_DIR)

    ## Use the backup of PostgreSQL source code.
    #if constants.MYSQL_CHECKOUT_ROOT.exists():
    #    utils.remove_directory(constants.MYSQL_CHECKOUT_ROOT)
    #    utils.copy_directory(
    #        constants.MYSQL_SOURCE_BACKUP, constants.MYSQL_CHECKOUT_ROOT
    #    )
    #pgs.clone_mysql_source()


def main():

    oracle_str = "NOREC"
    is_non_deter = False
    try:
        opts, args = getopt.getopt(sys.argv[1:], "O:F:", ["oracle=", "Feedback=", "non-deter"])
    except getopt.GetoptError:
        print("Arguments parsing error")
        exit(1)
    for opt, arg in opts:
        if opt in ("-O", "--oracle"):
            oracle_str = arg
            print("Using oracle: %s " % (oracle_str))
        elif opt in ("-F", "--Feedback"):
            # Ignore this flag in the bisecting. 
            pass
        elif opt in ("--non-deter"):
            is_non_deter = True
            print("Using non-deterministic queries. ")
        else:
            print("Error. Input arguments not supported. \n")
            exit(1)

    debug_level = "DEBUG"
    setup_logger(debug_level)
    setup_env()

    enter_bisecting_mode(oracle_str, is_non_deter)


if __name__ == "__main__":
    main()
