import os

CUR_WORKDIR = "/home/sqlite/bisecting"

SQLITE_DIR = "/home/sqlite/sqlite_bisecting_binary/"
# Change to your own sqlite3 repo root dir.
SQLITE_BLD_DIR = os.path.join(SQLITE_DIR, "bld")
SQLITE_BRANCH = "master"

# Change to your own query_samples dir.
BUG_SAMPLE_DIR = os.path.join(CUR_WORKDIR, "bug_samples/")

LOG_OUTPUT_FILE = os.path.join(CUR_WORKDIR, "bisecting_sqlite_log.txt")
UNIQUE_BUG_OUTPUT_DIR = os.path.join(BUG_SAMPLE_DIR, "unique_bug_output")

COMPILE_THREAD_COUNT = 1
COMMIT_SEARCH_RANGE = 1

BEGIN_COMMIT_ID = ""  # INCLUDED!!!   Earlier commit.
END_COMMIT_ID = ""  # INCLUDED!!!   Latest commit or the bug triggering commit.

KNOWN_BUGGY_COMMIT = [
            "8981b904b545ad056ad2f6eb0ebef6a6b9606b5b",
            "efad2e23668ea5cbd744b6abde43058de45fb53",
            "f761d937c233ab7e1ac1a187a80c45846a8d1c52",
            "83193d0133328a28dbd4d4bbd1f9747158d253a2",
            "6bfc167a67586d465ed995ae6dd3216967fc83c6",
            "384f5c26f48b92e8bfcb168381d4a8caf3ea59e7",
            "431704375e0c1bf93902e6ef417c02abe4a35148",
            "39129ce8d9cb0101bad783fa06365332e0ddd83d",
            "b95e1193d58be876cffb061424aae2e13115c338",
            "8b8446fc21c194dbd92c57fe2527b1ec08067077",
            "7e508f1ee2d671976fd1dbe4a8fdbc840ba39b97",
            "c27ea2ae8df4207e6b2479b46904c73d7cd1775f",
            "3072b537f5963361a53a74ff2ad8f2c87e93c7c0",
            "415ae725cb652b24d9630cf4003dbe99322ff154"
        ]
