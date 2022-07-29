import re
from socket import socket
import time
import os
import shutil
import subprocess
import atexit
import signal
import psutil
import MySQLdb

from afl_config import *

print("Running mysql_rebooter.py script in mktime: %d" % (time.mktime(time.localtime())))

is_restarted_mysql = False

# Read required info from the local file
all_share_mem_file = "./all_share_mem_file.txt"
all_share_mem_file = open(all_share_mem_file, "r")


# Read cur_shm_str
all_mysql_p_list = dict()
for cur_share_mem_line in all_share_mem_file.readlines():
    cur_share_mem_line = cur_share_mem_line.replace("\n", "")
    cur_inst_id = cur_share_mem_line.split(":")[0]
    cur_inst_id = int(cur_inst_id)
    cur_shm_str = cur_share_mem_line.split(":")[1]
    all_mysql_p_list[cur_inst_id] = cur_shm_str
    print("Received cur_inst_id %d, cur_shm_str: %s. \n" % (cur_inst_id, cur_shm_str))



# Read prevoius shutdown time
all_prev_shut_time_file = open("./all_prev_shut_time_file.txt", "r")
all_prev_shutdown_time = dict()

for cur_prev_shut_time_file_line in all_prev_shut_time_file.readlines():
    cur_prev_shut_time_file_line = cur_prev_shut_time_file_line.replace("\n", "")
    prev_inst_id = cur_prev_shut_time_file_line.split(":")[0]
    prev_inst_id = int(prev_inst_id)
    prev_shut_time = float(cur_prev_shut_time_file_line.split(":")[1])
    all_prev_shutdown_time[prev_inst_id] = prev_shut_time
    print("Received previous shutdown time: %d: %d" % (prev_inst_id, prev_shut_time))

all_prev_shut_time_file.close()

for prev_shutdown_time_idx,_ in all_prev_shutdown_time.items():
    prev_shutdown_time = all_prev_shutdown_time[prev_shutdown_time_idx]
    if (time.mktime(time.localtime())  -  prev_shutdown_time)  > MYSQL_REBOOT_TIME_GAP: # 60 sec, restart mysql
        print("******************\nBegin scheduled MYSQL restart. ID: %d\n" % (prev_shutdown_time_idx))
        # Politely, restart MySQL. 
        cur_port_num = port_starting_num + prev_shutdown_time_idx - starting_core_id
        socket_path = "/tmp/mysql_" + str(prev_shutdown_time_idx) + ".sock"
        try:
            db = MySQLdb.connect(host="localhost",    # your host, usually localhost
                 user="root",         # your username
                 passwd="",  # your password
                 port=cur_port_num,
                 unix_socket=socket_path,
                 db="test_init")        # name of the data base
        except MySQLdb._exceptions.OperationalError:
            print("MYSQL server down, not recovered yet. \n\n\n")
            continue
        
        cur = db.cursor()
        cur.execute("SHUTDOWN;")
        db.close()
        time.sleep(1)

        print("MYSQL shutdown completed. ID: %d\n\n\n" % (prev_shutdown_time_idx))
        # 2 more seconds would be waited until the new MYSQL is being started. Thus, there would be more than 2 seconds between every MYSQL process restart. 
        # The actual restart of mysql is being handle by the same MYSQL crash handler. (Above)
        continue

time.sleep(1)

# SHUTDOWN MYSQL, periodically, using pkill. 
SHUTDOWN_COMMAND = "pkill mysqld"
print("Running SHUTDOWN_COMMAND: %s" % (SHUTDOWN_COMMAND))
p = subprocess.Popen(
                    SHUTDOWN_COMMAND,
                    shell=True,
                    stderr=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stdin=subprocess.DEVNULL
                    ).communicate()

print("Finished running SHUTDOWN COMMAND. \n")

for cur_inst_id,_ in all_mysql_p_list.items():
    cur_shm_str = all_mysql_p_list[cur_inst_id]
    cur_port_num = port_starting_num + cur_inst_id - starting_core_id
    socket_path = "/tmp/mysql_" + str(cur_inst_id) + ".sock"
    is_server_down = False
    try:
        db = MySQLdb.connect(host="localhost",    # your host, usually localhost
                 user="root",         # your username
                 passwd="",  # your password
                 port=cur_port_num,
                 unix_socket=socket_path,
                 db="test_init")        # name of the data base
        db.close()
    except MySQLdb._exceptions.OperationalError:
        is_server_down = True
    
    if not is_server_down:
        continue
    # for proc in psutil.process_iter():
    #     # check whether the process name matches
    #     cur_proc_name = proc.name()
    #     print(cur_proc_name)
    ### CANNOT FIND THE MYSQL SERVER. CRASHED? 
    print("*****************\nMySQL Server with ID %d gone. Save the data folder and resume now. \n" %(cur_inst_id))
    # continue
    ### RECOVERY!!!
    cur_mysql_data_dir_str = os.path.join(mysql_root_dir, "data_all/data_" + str(cur_inst_id))

    try:
        ### DELETE THE ORIGINAL data folder, then reinvoke mysql!
        if os.path.isdir(cur_mysql_data_dir_str):
            shutil.rmtree(cur_mysql_data_dir_str)
        # print("Recovering new data dir: %s to %s"  % (mysql_src_data_dir, cur_mysql_data_dir_str))
        shutil.copytree(mysql_src_data_dir, cur_mysql_data_dir_str)
    except shutil.Error as err:
        print("Copy new data folder failed! Try again later. ID: %d. " % (cur_inst_id))
        break
    except OSError as err:
        print("Copy new data folder failed! Try again later. ID: %d. " % (cur_inst_id))
        break
    # Reinvoke mysql
    # Prepare for env shared by the fuzzer and mysql. 
    # Set up SQLRight output folder
    cur_output_dir_str = "./outputs"
    cur_output_file = os.path.join(cur_output_dir_str, "output.txt")
    if os.path.isfile(cur_output_file):
        os.remove(cur_output_file)
    mysql_bin_dir = os.path.join(mysql_root_dir, "bin/mysqld")
    
    # Start the MYSQL instance
    ori_workdir = os.getcwd()
    mysql_command = [
        "screen",
        "-dmS",
        "test" + str(cur_inst_id),
        "bash", "-c", 
        "'",    # left quote
        mysql_bin_dir,
        "--basedir=" + mysql_root_dir,
        "--datadir=" + cur_mysql_data_dir_str,
        "--port=" + str(cur_port_num),
        "--socket=" + socket_path,
        "--performance_schema=OFF",
        "'"  # right quote
    ]
    mysql_modi_env = dict()
    mysql_modi_env["__AFL_SHM_ID"] = cur_shm_str
    mysql_command = " ".join(mysql_command)
    print("Running mysql command: __AFL_SHM_ID=" + cur_shm_str + " " + mysql_command, end="\n")
    p = subprocess.Popen(
                        mysql_command,
                        shell=True,
                        stderr=subprocess.DEVNULL,
                        stdout=subprocess.DEVNULL,
                        stdin=subprocess.DEVNULL,
                        env = mysql_modi_env
                        )
    print("Finished running popen. \n")
    time.sleep(1)

    is_restarted_mysql = True


# Update previous restart time. 

if is_restarted_mysql:
    all_prev_shut_time_file = open("./all_prev_shut_time_file.txt", "w")
    for cur_inst_id, _ in all_prev_shutdown_time.items():
        new_shutdown_time = time.mktime(time.localtime())
        all_prev_shut_time_file.write("%d:%s\n" % (cur_inst_id, new_shutdown_time))
        print("New shutdown time: %d:%d"  % (cur_inst_id, new_shutdown_time))

    all_prev_shut_time_file.close()

