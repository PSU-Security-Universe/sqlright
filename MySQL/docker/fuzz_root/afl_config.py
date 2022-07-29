import os

mysql_root_dir = "/home/mysql/mysql-server/bld"
mysql_src_data_dir = os.path.join(mysql_root_dir, "data_all/ori_data")
current_workdir = os.getcwd()

starting_core_id = 0
parallel_num = 5
port_starting_num = 9000

MYSQL_REBOOT_TIME_GAP = 60
