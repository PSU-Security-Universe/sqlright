#!/usr/bin/env python3
import os

src_dir = "./postgres_log"
dest_dir = "./postgres_log_clean"

if not os.path.isdir(dest_dir):
    os.mkdir(dest_dir)

idx = 0

for cur_file_name in sorted(os.listdir(src_dir)):
    src_file_name = os.path.join(src_dir, cur_file_name)
    src_file_fd = open(src_file_name, "r")

    dest_file_name = os.path.join(dest_dir, cur_file_name)
    dest_file_fd = open(dest_file_name, "w")

    for cur_line in src_file_fd.readlines():
        if ("\\c" in cur_line):
            continue
        cur_line = cur_line.split("] ")
        if (len(cur_line) == 2):
            # print("Parsing line: " + cur_line[1])
            dest_file_fd.write(cur_line[1])
    if idx > 200:
        break
    idx += 1

print("Done")
