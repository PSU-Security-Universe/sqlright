from enum import Enum
import re

from bi_config import LOG_OUTPUT_FILE


class RESULT(Enum):
    PASS = 1
    FAIL = 0
    ERROR = -1
    ALL_ERROR = -1
    FAIL_TO_COMPILE = -2
    SEG_FAULT = -3


class BisectingResults:
    query = []
    first_buggy_commit_id: str = ""
    first_corr_commit_id: str = ""
    final_res_flag: RESULT = RESULT.PASS
    is_error_returned_from_exec: bool = ""
    last_buggy_res_str_l = []
    last_buggy_res_flags_l = []
    unique_bug_id = "Unknown"
    is_bisecting_error: bool = False
    bisecting_error_reason: str = ""


log_out_f = open(LOG_OUTPUT_FILE, "w")


def log_out_line(s):
    print(s)
    log_out_f.write(str(s) + "\n")


def is_string_only_whitespace(input_str: str):
    if re.match(r"""^[\s]*$""", input_str, re.MULTILINE | re.IGNORECASE):
        return True  # Only whitespace
    return False  # Not only whitespace
