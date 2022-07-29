import os
import shutil

input_folder = "./other_inputs_version/inputs_FULL"

new_input_folder = "./new_inputs"

if os.path.isdir(new_input_folder):
    shutil.rmtree(new_input_folder)

os.mkdir(new_input_folder)

files = os.listdir(input_folder)
files_sorted_by_size = sorted(files, key=lambda files: os.path.getsize(os.path.join(input_folder, files)), reverse=True)  
files_sorted_by_size_trim = files_sorted_by_size[:300]

for i_file in files_sorted_by_size_trim:
    file_path = os.path.join(input_folder, i_file)
    if not os.path.isfile(file_path):
        continue

    cur_fd = open(file_path, "r", encoding='UTF-8', errors = "replace")
    all_uniq_line_list = []
    all_lines = ""

    line_num = 0
    for cur_line in cur_fd.readlines():
        if len(cur_line) > 700:
            continue
        if cur_line[:5] in all_uniq_line_list:
            # Only saving unique lines. 
            continue
        if cur_line[:6] == "SELECT" or cur_line[:6] == "select":
            # Do not save select. Leave them to initlib
            print("Found select\n")
            continue
        # if (cur_line[:7] == "EXPLAIN" or cur_line[:7] == "explain"):
        #     print("Found explain\n")
        #     continue
        all_lines += cur_line
        all_uniq_line_list.append(cur_line[:10])

        if line_num > 60:
            break
        
        line_num += 1
    
    if all_lines != "":
        out_file_path = os.path.join(new_input_folder, i_file)
        out_fd = open(out_file_path, "w", encoding='UTF-8', errors = "replace")
        out_fd.write(all_lines)
        out_fd.close()
    
    cur_fd.close()
        

