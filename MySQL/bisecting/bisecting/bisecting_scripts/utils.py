import json
import os
import re
import shlex
import shutil
import subprocess
from pathlib import Path
from typing import List
import time

import constants
from loguru import logger


def json_dump(json_obj, json_file, sort_keys=False):
    with open(json_file, "w") as f:
        json.dump(json_obj, f, indent=2, sort_keys=sort_keys)


def json_load(json_file):
    with open(json_file) as f:
        obj = json.load(f)
    return obj


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


def remove_file(file: Path):
    if file.exists():
        file.unlink()
    return

def remove_file(file: str):
    if os.path.isfile(file):
        os.remove(file)
    return

def remove_directory_error_helper(func, path, exc_info):
    # Force stop all mysqld process. And then wait for a few seconds.
    command = "pkill mysqld"
    subprocess.run(command, shell=True)
    time.sleep(7)


def remove_directory(directory: Path):
    directory = Path(directory)
    if directory.exists():
        shutil.rmtree(directory, onerror=remove_directory_error_helper)

    if directory.exists():
        shutil.rmtree(directory)
    return

def remove_directory(directory: str):
    if os.path.isdir(directory):
        shutil.rmtree(directory, onerror=remove_directory_error_helper)

    if os.path.isdir(directory):
        shutil.rmtree(directory)
    return

def copy_file(src: Path, dest: Path):
    shutil.copyfile(src, dest)
    return

def copy_file(src: str, dest: str):
    if os.path.isfile(src):
        shutil.copyfile(src, dest)
    else:
        logger.warning("Copy file src: %s not exists. " % (src))
    return

def copy_directory(src: Path, dest: Path):
    shutil.copytree(src, dest)

def copy_directory(src: str, dest: str):
    if os.path.isdir(src):
        shutil.copytree(src, dest)
    else:
        logger.warning("Copy directory src: %s not exists. " % (src))
    return


def is_string_only_whitespace(string: str):
    pattern = r"""^[\s]*$"""
    flags = re.MULTILINE | re.IGNORECASE
    matched = re.match(pattern, string, flags)
    return bool(matched)


#def load_failed_commit() -> List[str]:
#    return (
#        json_load(constants.FAILED_COMPILE_COMMITS)
#        if constants.FAILED_COMPILE_COMMITS.exists()
#        else []
#    )


#def is_failed_commit(hexsha: str) -> bool:
#    commits = load_failed_commit()
#    return hexsha.strip() in commits


#def dump_failed_commit(hexsha: str):
#    hexsha = hexsha.strip()
#    commits = load_failed_commit()
#    if hexsha not in commits:
#        commits.append(hexsha)
#        json_dump(commits, constants.FAILED_COMPILE_COMMITS)
#
#
#def remove_failed_commit(hexsha: str):
#    hexsha = hexsha.strip()
#    commits = load_failed_commit()
#    if hexsha in commits:
#        commits.remove(hexsha)
#        json_dump(commits, constants.FAILED_COMPILE_COMMITS)
