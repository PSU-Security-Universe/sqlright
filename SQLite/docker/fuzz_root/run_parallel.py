import re
import time
import os
import shutil
import subprocess
import atexit
import getopt
import sys

oracle_str = ""


sqlite_root_dir = "/home/sqlite/sqlite"
sqlite_bin = os.path.join(sqlite_root_dir, "sqlite3")
current_workdir = os.getcwd()

starting_core_id = 0
parallel_num = 5

timeout_ms = 2000 # not used.

# Parse the command line arguments:
output_dir_str = "/home/sqlite/fuzzing/fuzz_root/outputs"
oracle_str = "NOREC"
feedback_str = ""
explain_flag = False
is_non_deter = False

try:
    opts, args = getopt.getopt(sys.argv[1:], "o:c:n:O:F:T:E", ["odir=", "start-core=", "num-concurrent=", "oracle=", "feedback=", "timeout=", "non-deter"])
except getopt.GetoptError:
    print("Arguments parsing error")
    exit(1)
for opt, arg in opts:
    if opt in ("-o", "--odir"):
        output_dir_str = arg
#        print("Using IN-DOCKER (not host system output dir) output dir: %s" % (output_dir_str))
    elif opt in ("-c", "--start-core"):
        starting_core_id = int(arg)
        print("Using starting_core_id: %d" % (starting_core_id))
    elif opt in ("-n", "--num-concurrent"):
        parallel_num = int(arg)
        print("Using num-concurrent: %d" % (parallel_num))
    elif opt in ("-O", "--oracle"):
        oracle_str = arg
        print("Using oracle: %s " % (oracle_str))
    elif opt in ("-F", "--feedback"):
        feedback_str = arg
        print("Using feedback: %s " % (feedback_str))
    elif opt in ("-T", "--timeout"):
        timeout_ms = int(arg)
        print("Using timeout: %d " % (timeout_ms))
    elif opt in ("-E"):
        explain_flag = True
        print("Using Explain flag. ")
    elif opt in ("--non-deter"):
        is_non_deter = True
        print("Using Non-Deterministic Behavior. ")
    else:
        print("Error. Input arguments not supported. \n")
        exit(1)

sys.stdout.flush()

for cur_inst_id in range(starting_core_id, starting_core_id + parallel_num, 1):
    print("###############\nSetting up core_id: " + str(cur_inst_id))

    # Set up SQLRight output folder
    cur_output_dir_str = os.path.join(output_dir_str, "outputs_" + str(cur_inst_id - starting_core_id))
    if not os.path.isdir(cur_output_dir_str):
        os.mkdir(cur_output_dir_str)
    
    cur_output_file = os.path.join(cur_output_dir_str, "output.txt")
    cur_output_file = open(cur_output_file, "w")

    fuzzing_command = []


    fuzzing_command = [
        "./afl-fuzz",
        "-i", "./inputs",
        "-o", cur_output_dir_str,
        "-c", str(cur_inst_id),
        "-O", str(oracle_str)
    ]

    if explain_flag:
        fuzzing_command.append("-E")

    if feedback_str != "":
        fuzzing_command.append("-F " + str(feedback_str))

    if is_non_deter == True:
        # The non-deter flag for the afl-fuzz is '-w'.
        fuzzing_command.append("-w")

    fuzzing_command.append(" -- ")
    fuzzing_command.append(sqlite_bin)
    fuzzing_command.append("&")

    fuzzing_command = " ".join(fuzzing_command)
    print("Running fuzzing command: " + fuzzing_command)

    modi_env = dict()
    modi_env["AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES"] = "1"
    modi_env["AFL_SKIP_CPUFREQ"] = "1"

    p = subprocess.Popen(
                        fuzzing_command,
                        cwd=os.getcwd(),
                        shell=True,
                        stderr=subprocess.DEVNULL,
                        stdout=subprocess.DEVNULL,
                        stdin=subprocess.DEVNULL,
                        env=modi_env
                        )

print("Finished launching the fuzzing. Now monitor the mysql process. ")

print("#############\nFinished launching the fuzzing. \n\n\n")

while True:
    time.sleep(100)
