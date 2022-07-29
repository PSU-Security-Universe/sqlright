import shutil
import os

src_folder = "/home/luy70/Desktop/SQLRight_DBMS/postgres/postgres/src/test/"
dest_folder = "./new_inputs/"

for root, dirs, files in os.walk(src_folder, topdown=False):
    for cur_file in files:
        if cur_file[-4:] != ".sql":
            continue
        file_path = os.path.join(root, cur_file)
        shutil.copy(file_path, dest_folder)
        print("Copied file name: %s" % (file_path))

