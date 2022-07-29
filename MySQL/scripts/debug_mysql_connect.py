import os

with open("fuzz_root/outputs_0/output.txt") as f:
    contents = f.read()


start_pos = contents.find("do_library_initialize")
stop_pos = contents.find("Column count of mysql.user is wrong")
contents = contents[start_pos: stop_pos]
lines = [line for line in contents.splitlines() if "Attempting dry run" in line]
for line in lines:
    start_pos = line.find("orig:")
    stop_pos = line.rfind("'")
    input_file_name = line[start_pos+len("orig:"): stop_pos]
    input_file_path = os.path.join("fuzz_root/inputs",  input_file_name)
    # print(input_file_path)
    with open(input_file_path) as f:
        input_lines = f.readlines()
        for input_line in input_lines:
            print(input_line,end="")
