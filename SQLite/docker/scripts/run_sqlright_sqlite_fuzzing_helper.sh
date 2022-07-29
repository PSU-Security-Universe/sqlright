#!/bin/bash -e

# This file is used for start the SQLRight MySQL fuzzing inside the Docker env.
# entrypoint: bash

chown -R sqlite:sqlite /home/sqlite/fuzzing

SCRIPT_EXEC=$(cat << EOF

mkdir -p /home/sqlite/fuzzing/Bug_Analysis/bug_samples

cd /home/sqlite/fuzzing/fuzz_root

cp /home/sqlite/src/afl-fuzz ./

printf "\n\n\n\nStart fuzzing. \n\n\n\n\n"

python3 run_parallel.py -o /home/sqlite/fuzzing/fuzz_root/outputs -E $@

EOF
)

su -c "$SCRIPT_EXEC" sqlite

echo "Finished\n"
