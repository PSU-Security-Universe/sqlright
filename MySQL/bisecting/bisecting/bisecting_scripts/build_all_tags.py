import vcs
import mysql
from rich.progress import track


tagrefs = vcs.get_all_sorted_tags()
for tagref in track(tagrefs[::-1]):
    commit_hexsha = tagref.commit.hexsha
    mysql.setup_mysql_commit(commit_hexsha)

