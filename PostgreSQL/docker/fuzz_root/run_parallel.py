import re
import time
import os
import shutil
import subprocess
import atexit
import getopt
import sys

postgres_root_dir = "/home/postgres/postgres/bld/"
postgres_src_data_dir = os.path.join(postgres_root_dir, "data_all/ori_data")
current_workdir = os.getcwd()

starting_core_id = 0
parallel_num = 5
port_starting_num = 7000

all_fuzzing_p_list = []
all_postgres_p_list = []
shm_env_list = []

#def exit_handler():
#    for fuzzing_instance in all_fuzzing_p_list:
#        fuzzing_instance.kill()
#    for postgre_instance in all_postgres_p_list:
#        postgre_instance.kill()
#    return


def check_pid(pid:int):
    """Check whether pid are still running. """
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    else:
        return True

#atexit.register(exit_handler)


# Parse the command line arguments:
output_dir_str = ""
oracle_str = "NOREC"
feedback_str = ""

try:
    opts, args = getopt.getopt(sys.argv[1:], "o:c:n:O:F:", ["odir=", "start-core=", "num-concurrent=", "oracle=", "feedback="])
except getopt.GetoptError:
    print("Arguments parsing error")
    exit(1)
for opt, arg in opts:
    if opt in ("-o", "--odir"):
        output_dir_str = arg
        print("Using output dir: %s" % (output_dir_str))
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
    else:
        print("Error. Input arguments not supported. \n")
        exit(1)

sys.stdout.flush()

if os.path.isfile(os.path.join(os.getcwd(), "shm_env.txt")):
    os.remove(os.path.join(os.getcwd(), "shm_env.txt"))

for cur_inst_id in range(starting_core_id, starting_core_id + parallel_num, 1):
    print("Setting up core_id: " + str(cur_inst_id))

    # Set up the postgre data folder first. 
    cur_postgre_data_dir_str = os.path.join(postgres_root_dir, "data_all/data_" + str(cur_inst_id-starting_core_id))
    if not os.path.isdir(cur_postgre_data_dir_str):
        shutil.copytree(postgres_src_data_dir, cur_postgre_data_dir_str)

    # Set up SQLRight output folder
    cur_output_dir_str = ""
    if output_dir_str != "":
        cur_output_dir_str = output_dir_str + "/outputs_"  + str(cur_inst_id - starting_core_id)
    else:
        cur_output_dir_str = "./outputs/outputs_" + str(cur_inst_id - starting_core_id)
    if not os.path.isdir(cur_output_dir_str):
        os.mkdir(cur_output_dir_str)

    cur_output_file = os.path.join(cur_output_dir_str, "output.txt")
    cur_output_file = open(cur_output_file, "w")
    
    # Prepare for env shared by the fuzzer and postgres. 
    cur_port_num = port_starting_num + cur_inst_id - starting_core_id

    # Start running the SQLRight fuzzer. 
    fuzzing_command = "./afl-fuzz -t 2000 -m 2000 " \
                        + " -P " + str(cur_port_num) \
                        + " -i ./inputs " \
                        + " -o " + cur_output_dir_str \
                        + " -c " + str(cur_inst_id) \
                        + " -O " + oracle_str

    if feedback_str != "":
        fuzzing_command += " -F " + feedback_str

    fuzzing_command +=  " aaa " + " & "

    modi_env = dict()
    modi_env["AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES"] = "1"
    modi_env["AFL_SKIP_CPUFREQ"] = "1"

    print("Running fuzzing command: " + fuzzing_command)

    p = subprocess.Popen(
                        [fuzzing_command],
                        cwd=os.getcwd(),
                        shell=True,
                        stderr=subprocess.DEVNULL,
                        stdout=subprocess.DEVNULL,
                        stdin=subprocess.DEVNULL,
                        env=modi_env
                        )
    all_fuzzing_p_list.append(p)

    # Read the current generated shm_mem_id
    while not (os.path.isfile(os.path.join(os.getcwd(), "shm_env.txt"))):
        time.sleep(1)
    shm_env_fd = open(os.path.join(os.getcwd(), "shm_env.txt"))
    cur_shm_str = shm_env_fd.read()
    shm_env_list.append(cur_shm_str)
    shm_env_fd.close()

    os.remove(os.path.join(os.getcwd(), "shm_env.txt"))

    # Start the PostgreS instance
    ori_workdir = os.getcwd()
    os.chdir(postgres_root_dir)

    postgre_bin_dir = os.path.join(postgres_root_dir, "bin/postgres")
    postgre_command = "__AFL_SHM_ID=" + cur_shm_str + " " + postgre_bin_dir + " -D " + cur_postgre_data_dir_str + " --port=" + str(cur_port_num) + " & "
    print("Running postgres command: " + postgre_command, end="\n\n")
    p = subprocess.Popen(
                        [postgre_command],
                        cwd=postgres_root_dir,
                        shell=True,
                        stderr=subprocess.DEVNULL,
                        stdout=subprocess.DEVNULL,
                        stdin=subprocess.DEVNULL,
                        )
    all_postgres_p_list.append(p)
    os.chdir(ori_workdir)

    sys.stdout.flush()

print("Finished launching the fuzzing. ")
sys.stdout.flush()

while True:
#    for idx in range(len(all_postgres_p_list)):
#        cur_postgre_p = all_postgres_p_list[idx]
#        cur_postgre_pid = cur_postgre_p.pid
#        if not check_pid(cur_postgre_pid):
#
#            # PostgreS process crashed. Restart Postgres. 
#            all_postgres_p_list.remove(cur_postgre_p)
#            cur_shm_str = shm_env_list[idx]
#            cur_postgre_data_dir_str = os.path.join(postgres_root_dir, "data_all/data_" + str(idx))
#
#            postgre_command = "__AFL_SHM_ID=" + cur_shm_str +  " ./bin/postgres -D " + cur_postgre_data_dir_str + " & "
#            print("PostgreS PID: " + str(cur_postgre_pid) + " crashed. ")
#            print("Restarting postgres command: " + fuzzing_command, end="\n\n")
#            p = subprocess.Popen(
#                                [postgre_command],
#                                cwd=postgres_root_dir,
#                                shell=False,
#                                stderr=subprocess.DEVNULL,
#                                stdout=subprocess.DEVNULL,
#                                stdin=subprocess.DEVNULL,
#                                )
#            all_postgres_p_list.insert(idx, p)
    
    # Check postgres every 10 seconds. 
    time.sleep(1000)
