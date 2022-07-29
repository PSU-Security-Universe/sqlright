#!/usr/bin/env python3

import os

r_dir = "./t"
i_dir = "./include/"
t_dir = "./new_inputs"

def read_files(cur_file, t_f):
    print("Reading file: %s" % (cur_file))
    ori_file_name = cur_file.split("/")[-1]
    if not os.path.isfile(cur_file):
        return
    cur_file = open(cur_file, errors = "ignore")
    t_file = open(t_f, "a")

    for cur_line in cur_file.readlines():
        cur_line = cur_line.replace("\n", "")
        # print("Getting cur_line: %s" % (cur_line))
        if len(cur_line) > 1 and "#" == cur_line[0]:
            continue
        if "--source " in cur_line:
            if "include/" in cur_line:
                include_file = cur_line.split("include/")[1]
                if include_file == ori_file_name:
                    continue
                include_file = os.path.join(i_dir, include_file)
                print("Getting include_file %s" % (include_file))
                if include_file == "":
                    continue
                read_files(include_file, t_f)
            else:
                include_file = cur_line.split("--source ")[1]
                if include_file == ori_file_name:
                    continue
                include_file = os.path.join(r_dir, include_file)
                print("Getting include_file %s" % (include_file))
                if include_file == "":
                    continue
                read_files(include_file, t_f)
            continue
        if len(cur_line) > 2 and "--" in cur_line:
            cur_line = cur_line[:cur_line.find("--")]
        if len(cur_line) < 2:
            continue
        if cur_line == "Warnings:":
            continue
        if len(cur_line) > 2 and cur_line[:2] == "if":
            continue
        if len(cur_line) > 7 and cur_line[:7] == "Warning":
            continue
        if "mtr.add_suppression" in cur_line:
            continue
        if len(cur_line) > 3 and cur_line[:3] == "let":
            continue
        t_file.write(cur_line)
        if len(cur_line) > 1 and cur_line[-1] == ";":
            t_file.write("\n")


for cur_file in os.listdir(r_dir):
    if ".opt" in cur_file:
        continue
    # print("Reading file: %s" % (cur_file))
    t_f = os.path.join(t_dir, cur_file)
    cur_file = os.path.join(r_dir, cur_file)
    read_files(cur_file, t_f)
