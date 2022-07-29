from pathlib import Path
import os

import constants
import utils
# import pymysql
from loguru import logger
import subprocess
import time

def force_copy_data_backup(hexsha: str):
    backup_data = os.path.join(constants.MYSQL_ROOT, hexsha, "data_all/ori_data")
    cur_data = os.path.join(constants.MYSQL_ROOT, hexsha, "data_all/data_0")
    utils.remove_directory(cur_data)
    utils.copy_directory(backup_data, cur_data)


#def checkout_mysql_commit(hexsha: str):
#    # rsync_cmd = "rsync -avz -q -hH --delete {src}/ {dest}".format(
#    #     src=constants.MYSQL_SOURCE_BACKUP.absolute(),
#    #     dest=constants.MYSQL_CHECKOUT_ROOT.absolute(),
#    # )
#    # utils.execute_command(rsync_cmd)
#
#    checkout_cmd = f"git checkout {hexsha} --force"
#    utils.execute_command(checkout_cmd, cwd=constants.MYSQL_CHECKOUT_ROOT)
#
#    logger.debug(f"Checkout commit completed: {hexsha}")

def get_mysqld_binary(cur_dir:str):
    if os.path.isdir(os.path.join(cur_dir, "share")) and os.path.isdir(os.path.join(cur_dir, "bin")):
        # The third scenario, has (bin, extra, scripts, share, support-files)
        command = "./bin/mysqld"
        return command

    elif os.path.isdir(os.path.join(cur_dir, "bin/client")):
        # The second scenario, has (client, scripts and sql)
        command = "./bin/sql/mysqld"
        return command
    else:
        # The first scenario, all binaries directly in bin dir.
        command = "./bin/mysqld"
        return command


def get_mysql_binary(cur_dir:str):
    if os.path.isdir(os.path.join(cur_dir, "share")) and os.path.isdir(os.path.join(cur_dir, "bin")):
        # The third scenario, has (bin, extra, scripts, share, support-files)
        command = "./bin/mysql"
        return command

    elif os.path.isdir(os.path.join(cur_dir, "bin/client")):
        # The second scenario, has (client, scripts and sql)
        command = "./bin/client/mysql"
        return command
    else:
        # The first scenario, all binaries directly in bin dir.
        command = "./bin/mysql"
        return command

def start_mysqld_server(hexsha: str):

    p = subprocess.run("pkill mysqld",
                        shell=True,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        stdin=subprocess.DEVNULL
                        )

    cur_mysql_root = os.path.join(constants.MYSQL_ROOT, hexsha)
    cur_mysql_data_dir = os.path.join(cur_mysql_root, "data_all/data_0")
    cur_output_file = os.path.join(constants.BISECTING_SCRIPTS_ROOT, "mysql_output.txt")

    # Firstly, restore the database backup. 
    force_copy_data_backup(hexsha)

    logger.debug("Starting mysqld server with hash: %s" % (hexsha))

    # And then, call MySQL server process. 
    mysql_command = [
        get_mysqld_binary(cur_mysql_root),
        "--basedir=" + str(cur_mysql_root),
        "--datadir=" + str(cur_mysql_data_dir),
        "--port=" + str(constants.MYSQL_SERVER_PORT),
        "--socket=" + str(constants.MYSQL_SERVER_SOCKET),
        "&"
    ]

    mysql_command = " ".join(mysql_command)

    p = subprocess.Popen(
                        mysql_command,
                        cwd=cur_mysql_root,
                        shell=True,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        stdin=subprocess.DEVNULL
                        )
    # Do not block the Popen, let it run and return. We will later use `pkill` to kill the mysqld process.
    time.sleep(2)

def execute_queries(queries: str, hexsha: str):
    
    cur_mysql_root = os.path.join(constants.MYSQL_ROOT, hexsha)

    mysql_client = get_mysql_binary(cur_mysql_root) + " -u root -N --socket=%s" % (constants.MYSQL_SERVER_SOCKET)

    clean_database_query = "DROP DATABASE IF EXISTS test_sqlright1; CREATE DATABASE IF NOT EXISTS test_sqlright1; "

    utils.execute_command(
        mysql_client, input_contents=clean_database_query, cwd=cur_mysql_root, timeout=1  # 3 seconds timeout. 
    )

    safe_queries = queries.split("\n")

    all_outputs = ""
    status = 0
    all_error_msg = ""
    for safe_query in safe_queries:
        safe_query = "USE test_sqlright1; " + safe_query

        output, status, error_msg = utils.execute_command(
            mysql_client, input_contents=safe_query, cwd=cur_mysql_root, timeout=3  # 3 seconds timeout. 
        )
        all_outputs += output
        all_error_msg += error_msg + "\n"

    queries = "\n".join(safe_queries)
    logger.debug(f"Query:\n\n{queries}")
    logger.debug(f"Result: \n\n{all_outputs}\n")
    logger.debug(f"Directory: {cur_mysql_root}")
    logger.debug(f"Return Code: {status}")

    if not all_outputs:
        return None, constants.RESULT.ALL_ERROR

#    if status not in (0, 1):
#        # 1 is the default return code if we terminate the MySQL.
#        return None, constants.RESULT.SEG_FAULT

    return parse_mysql_result(all_outputs)


def parse_mysql_result(mysql_output: str):
    def is_output_missing():
        return any(
            [
                mysql_output == "",
                mysql_output.count("BEGIN VERI") < 1,
                mysql_output.count("END VERI") < 1,
                # utils.is_string_only_whitespace(mysql_output)
            ]
        )

    if is_output_missing():
        # Missing the outputs from the opt or the unopt.
        # Returning None implying errors.
        return None, constants.RESULT.ALL_ERROR

    output_lines = mysql_output.splitlines()

    def parse_output_lines(opt: bool):
        i = int(not opt)
        begin_indexes = [
            idx for idx, line in enumerate(output_lines) if f"BEGIN VERI {i}" in line
        ]
        end_indexes = [
            idx for idx, line in enumerate(output_lines) if f"END VERI {i}" in line
        ]

        if len(begin_indexes) != len(end_indexes):
            logger.warning(
                f"the number of 'BEGIN VERI {i}' is not "
                f"equal to the number of 'END VERI {i}'."
            )

        result = []
        for begin_idx, end_idx in zip(begin_indexes, end_indexes):
            current_lines_int = [-1]

            current_lines = output_lines[begin_idx + 1 : end_idx]

            if not current_lines:
                continue

            if current_lines == " " or current_lines == "\n":
                continue

            result.append(current_lines)

        return result

    opt_results = parse_output_lines(opt=True)
    unopt_results = parse_output_lines(opt=False)
    logger.debug(f"opt_results: {opt_results}")
    logger.debug(f"unopt_results: {unopt_results}")
    all_result_pairs = [[opt, unopt] for opt, unopt in zip(opt_results, unopt_results)]

    return all_result_pairs, constants.RESULT.PASS
