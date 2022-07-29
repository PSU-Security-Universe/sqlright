'''This file is used for comparing coverage info between two SQLRight version. The extra coverage for 'dest_dir' would be mapped to the queue.'''
import os

src_dir = "" # Dir to the map_id_triggered.txt
dest_dir = "" # Dir to the queue_coverage_id folder. More coverage

cov_queue_map = dict()

with open(src_dir, errors='ignore') as src_fd, open(dest_dir, errors='ignore') as dest_fd:
    for cur_dest_line in dest_fd.readlines():
        cur_dest_line_list = cur_dest_line.split(',')
        cov_idx = cur_dest_line_list[0]
        file_name = cur_dest_line_list[-1]
        cov_queue_map[cov_idx] = file_name

    for cur_src_line in src_fd.readlines():
        cur_src_line_list = cur_src_line.split(',')
        cov_idx = cur_src_line_list[0]
        file_name = cur_src_line_list[-1]
        if cov_idx in cov_queue_map:
            del cov_queue_map[cov_idx]

all_res_files = set()
for cov_idx, cur_file in cov_queue_map.items():
    print("cov-queue mapping: %s : %s" % (cov_idx, cur_file))
    all_res_files.add(cur_file)

for cur_file in all_res_files:
    print("Result files for checking: %s" % (cur_file))