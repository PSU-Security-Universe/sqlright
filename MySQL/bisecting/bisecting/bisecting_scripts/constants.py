from enum import Enum
import os

BISECTING_SCRIPTS_ROOT = "/home/mysql/bisecting_scripts"
MYSQL_ROOT = "/home/mysql/mysql_binary"

BUG_SAMPLES_PATH = os.path.join(BISECTING_SCRIPTS_ROOT, "bug_samples")
LOG_OUTPUT_FILE = os.path.join(BISECTING_SCRIPTS_ROOT, "logs.txt")
UNIQUE_BUG_OUTPUT_DIR = os.path.join(BISECTING_SCRIPTS_ROOT, "bug_samples/unique_bug_output")
MYSQL_SORTED_COMMITS = os.path.join( BISECTING_SCRIPTS_ROOT, "assets/sorted_commits.json")

MYSQL_SERVER_SOCKET = "/tmp/mysql_0.sock"
MYSQL_SERVER_PORT = "8000"

class RESULT(Enum):
    PASS = 1
    FAIL = 0
    ERROR = -1
    ALL_ERROR = -1
    FAIL_TO_COMPILE = -2
    SEG_FAULT = -2

    @classmethod
    def has_value(cls, value):
        return value in cls._value2member_map_


class BisectingResults:
    query = []
    first_buggy_commit_id: str = "Unknown"
    first_corr_commit_id: str = "Unknown"
    final_res_flag: RESULT = RESULT.PASS
    is_error_returned_from_exec: bool = False
    last_buggy_res_str_l = []
    last_buggy_res_flags_l = []
    unique_bug_id_int = "Unknown"
    is_bisecting_error: bool = False
    bisecting_error_reason: str = ""
