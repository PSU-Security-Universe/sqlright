import git
import os
import sys
import utils
import vcs
import mysql_builder
from constants import *
from rich.progress import track
from loguru import logger

# Get all the basic information first
all_commit_hash = vcs.get_all_commits_hexsha()
all_tags = vcs.get_all_sorted_tags()
all_tags_commit = vcs.get_all_commits_from_tags()

logger.debug("Before cutting, getting all_commit_hash size: %d" % (len(all_commit_hash)))

# Cut the latest and earliest commit from list.
late_idx = 0
early_idx = 0
try:
    late_idx = all_commit_hash.index(LAST_COMMIT)
    early_idx = all_commit_hash.index(EARLY_COMMIT)
except ValueError:
    logger.debug("The EARLY_COMMIT:%s and LAST_COMMIT:%s is not setup correctly in the constant.py. " % (EARLY_COMMIT, LAST_COMMIT))

all_commit_hash = all_commit_hash[late_idx:early_idx]

logger.debug("After cutting beginning and ending commit, commit size is %d" % (len(all_commit_hash)))

# Filter the commit hashes. 
filtered_commit_hash = []
i = 0
for cur_commit_hash in all_commit_hash:
    if i < 2000 and i % 100 == 0:
        filtered_commit_hash.append(cur_commit_hash)
        i += 1
        continue
    for cur_tag_commit in all_tags_commit:
        if cur_tag_commit in cur_commit_hash:
            filtered_commit_hash.append(cur_commit_hash)
            break
    i += 1

logger.debug("Getting number %d of filtered_commit_hash. " % (len(filtered_commit_hash)))

filtered_commited_hash_output_dir = "/home/mysql/bisecting/filtered_commit_hash.json"
utils.json_dump(filtered_commit_hash, filtered_commited_hash_output_dir)

logger.debug("Dumped the filtered_commited_hash as json file in: %s" % (filtered_commited_hash_output_dir))

for cur_commit_hash in filtered_commit_hash:
    logger.debug("Begin compiling MySQL version: %s" % (cur_commit_hash))
    if mysql_builder.setup_mysql_commit(hexsha=cur_commit_hash):
        logger.debug("MySQL version %s compilation succeed" % (cur_commit_hash))
    else:
        logger.debug("MySQL version %s compilation failed" % (cur_commit_hash))
        exit(1)




