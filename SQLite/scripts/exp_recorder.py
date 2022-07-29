import os
from pathlib import Path
from datetime import datetime
import time
import subprocess

ORACLE_STR = " NOREC "
SQLITE_DIR = "/home/luy70/Squirrel_DBMS_Project/sqlite3_source/sqlite/"
SQLITE_MASTER_COMMIT_ID = "c00727ab583ea47f6962aa33dfc84f2d3723dc04_AFL"
BEGIN_CORE_ID = 10
EVAL_RESULT_ROOT = "/data/yu/Squirrel_DBMS_Fuzzing/eval_results/cov_exp_sqlite"


SQLITE_FUZZING_BINARY_PATH = os.path.join(
    SQLITE_DIR, "bld/%s/sqlite3" % SQLITE_MASTER_COMMIT_ID
)


def save_loop():
    now = datetime.utcnow().strftime("%m%d-%H%M")
    result_dir = Path(EVAL_RESULT_ROOT) / now
    result_dir.mkdir(parents=True, exist_ok=True)

    for fuzz_root_int in Path.cwd().glob("fuzz_root_*"):
        fuzzer_stats = fuzz_root_int / "fuzz_root_0/fuzzer_stats"
        bug_stats = fuzz_root_int / "fuzz_root_0/fuzzer_stats_correctness"
        plot_data = fuzz_root_int / "fuzz_root_0/plot_data"
        fuzz_bitmap = fuzz_root_int / "fuzz_root_0/fuzz_bitmap"
        # bugs_dir = fuzz_root_int / "Bug_Analysis/bug_samples"

        dest_dir = result_dir / fuzz_root_int.name
        if not dest_dir.exists():
            dest_dir.mkdir()

        command = f"cp {fuzzer_stats} {bug_stats} {plot_data} {fuzz_bitmap} {dest_dir}"
        os.system(command)
        # command = f"cp -r {bugs_dir} {dest_dir}"
        # os.system(command)
    return now


def setup_and_run_fuzzing():
    fuzz_root_dir = os.getcwd()
    for i in range(5):
        os.chdir(fuzz_root_dir)
        cur_fuzz_dir = os.path.join(fuzz_root_dir, "./fuzz_root_%d/fuzz_root_0/" % i)
        os.chdir(cur_fuzz_dir)

        fuzzing_command = (
            "AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1  ../afl-fuzz -i ./inputs/ -o ./ -E "
            + " -c "
            + str(BEGIN_CORE_ID + i)
            + " -O "
            + ORACLE_STR
            + " -- "
            + SQLITE_FUZZING_BINARY_PATH
            + " &"
        )

        p = subprocess.Popen(
            [fuzzing_command],
            cwd=cur_fuzz_dir,
            shell=True,
            stderr=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
        )
        print("Running with fuzzing commands: %s" % fuzzing_command)
    os.chdir(fuzz_root_dir)


setup_and_run_fuzzing()
starttime = time.time()
while True:
    now = save_loop()
    print(f"Save experiment stats files at {now}")
    time.sleep(1800.0 - ((time.time() - starttime) % 1800.0))
