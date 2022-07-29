import os
import shutil
from pathlib import Path
from collections import deque 

mysql_source_repo = "/home/server1/Documents/Projects/mysql-server"

header_queue = deque(["parsertest.h"])

def mysql_include_folder(header):
    pass

files = 0
failed_headers = set()
while header_queue:
    # Copy the header dependency in BFS.
    header_file = header_queue.popleft()

    # add deps into queue.
    with open(header_file) as f:
        lines = f.readlines()
    
    # filter include lines
    lines = [line.strip() for line in lines if line.startswith('#include "')]
    # remove unittest related header
    lines = [line for line in lines if "unittest" not in line]
    # add 'include' for header files
    local_headers = set()
    for line in lines:
        if "/" not in line:
            line = line[:line.find('"')+1] + "include/" + line[line.find('"')+1:]
            # if os.path.exists(os.path.join(mysql_source_repo, include_line)):
            #     line = include_line
            # else:
            #     packaging_line = line[:line.find('"')+1] + "packaging/rpm-common/" + line[line.find('"')+1:]
            #     line = packaging_line

        
        header_path = line[line.find('"')+1: line.rfind('"')]
        local_headers.add(header_path)
    
    # copy deps into local.
    for header_path in local_headers:
        if os.path.exists(header_path):
            continue
            
        mysql_header_path = os.path.join(mysql_source_repo, header_path)
        if not os.path.exists(mysql_header_path) and not header_path.startswith("include/"):
            header_path = f"include/{header_path}"
            mysql_header_path = os.path.join(mysql_source_repo, header_path)

            
        Path(header_path).parent.mkdir(parents=True, exist_ok=True)

        if not os.path.exists(mysql_header_path):
            # print(f"[x] {header_file} {header_path} -> {mysql_header_path}")
            failed_headers.add(header_path)
            continue
            
        
        shutil.copyfile(mysql_header_path, header_path)
        header_queue.append(header_path)
        files += 1

        cpp_file = str(Path(header_path).with_suffix(".cc"))
        mysql_cpp_path = os.path.join(mysql_source_repo, cpp_file)
        if os.path.exists(mysql_cpp_path):
            shutil.copyfile(mysql_cpp_path, cpp_file)
            # print(cpp_file, mysql_cpp_path, os.path.exists(cpp_file))
            header_queue.append(cpp_file)
            files += 1
        
        print(f"Queue: {len(header_queue)}, files: {files}")
        if len(header_queue) < 5:
            for path in header_queue:
                print(f"\t {path}")


print("Total:", files)
print("\nStill missing:")
for path in failed_headers:
    print(path)