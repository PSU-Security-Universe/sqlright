import pandas as pd

file = pd.read_csv("./SQLite/fuzz_root/fuzz_root/map_id_triggered.txt")

all_EH = file['EH'].to_list()

EH = [x for x in all_EH if x == 1]

print(str(len(EH)) + "/" + str(len(all_EH)))