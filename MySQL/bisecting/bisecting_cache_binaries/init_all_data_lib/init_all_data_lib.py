import os
import shutil
import subprocess
from loguru import logger

mysql_binary_dir = "/home/mysql/mysql_binary"

def execute_command(
    command_line: str, cwd=None, timeout=100000, input_contents="", failed_message="", output_file=None
):
    """Run a command, returning its output."""
    cwd = cwd or Path.cwd()
    # shell_command = shlex.split(command_line, posix=True)
    shell_command = command_line
    output = ""
    error_msg = ""

    logger.debug(f"Start to execute shell command: {command_line}")
    if output_file:
        with open(output_file, "w+") as output_pipe:
            process_handle = subprocess.Popen(
                shell_command,
                shell=True,
                stdin=subprocess.PIPE,
                stdout=output_pipe,
                stderr=output_pipe,
                cwd=cwd,
                errors="replace",
            )
    else:
        process_handle = subprocess.Popen(
            shell_command,
            shell=True,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=cwd,
            errors="replace",
        )

    try:
        # FIXME: input_contents should be bytes
        output, error_msg = process_handle.communicate(input_contents, timeout=timeout)
    except subprocess.TimeoutExpired:
        logger.exception(f"Timeout expired to execute command: {command_line}.")
    except Exception as e:
        logger.exception(e)
    finally:
        process_handle.kill()

    if error_msg:
        logger.error(error_msg)

    if process_handle.returncode != 0 and failed_message:
        logger.error(failed_message)

    return output, process_handle.returncode, error_msg


for hexsha in os.listdir(mysql_binary_dir):
    cur_dir = os.path.join(mysql_binary_dir, hexsha)
    if not os.path.isdir(cur_dir):
        continue
    cur_bin_dir = os.path.join(cur_dir, "bin")

    cur_data_dir = os.path.join(cur_dir, "data")
    if os.path.isdir(cur_data_dir):
        shutil.rmtree(cur_data_dir)
    if not os.path.isdir(cur_data_dir):
        os.mkdir(cur_data_dir)

    if os.path.isdir(os.path.join(cur_dir, "share")):
        # The third scenario, has (bin, extra, scripts, share, support-files)
        command = "chmod +x ./scripts/mysql_install_db && ./scripts/mysql_install_db --user=mysql --basedir=./ --datadir=./data"
        execute_command(command, cwd=cur_dir)
        if not os.path.isdir(os.path.join(cur_data_dir, "mysql")):
            print("Commit %s init failed. " % (hexsha) )
            exit(1)

    elif os.path.isdir(os.path.join(cur_bin_dir, "client")):
        # The second scenario, has (client, scripts and sql)
        command = "./bin/sql/mysqld --initialize-insecure --user=mysql --datadir=./data"
        execute_command(command, cwd=cur_dir)
        if not os.path.isdir(os.path.join(cur_data_dir, "mysql")):
            print("Commit %s init failed. " % (hexsha) )
            exit(1)
    else:
        # The first scenario, all binaries directly in bin dir.
        command = "./bin/mysqld --initialize-insecure --user=mysql --datadir=./data"
        execute_command(command, cwd=cur_dir)
        if not os.path.isdir(os.path.join(cur_data_dir, "mysql")):
            print("Commit %s init failed. " % (hexsha) )
            exit(1)

    cur_data_all_dir = os.path.join(cur_dir, "data_all")
    if os.path.isdir(cur_data_all_dir):
        shutil.rmtree(cur_data_all_dir)
    os.mkdir(cur_data_all_dir)

    shutil.move(cur_data_dir, os.path.join(cur_data_all_dir, "ori_data"))
    print("Commit %s init succeed. " % (hexsha))




    

