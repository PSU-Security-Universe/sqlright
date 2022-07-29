#!/bin/bash -e

# This file is used for start the SQLRight MySQL fuzzing inside the Docker env.
# entrypoint: bash

chown -R postgres:postgres /home/postgres/fuzzing

SCRIPT_EXEC=$(cat << EOF
# Setup data folder
cd /home/postgres/postgres/bld
./bin/initdb -D ./data
./bin/pg_ctl -D ./data start
./bin/createdb x
./bin/pg_ctl -D ./data stop
mkdir -p data_all
mv data data_all/ori_data

mkdir -p /home/postgres/fuzzing/Bug_Analysis/bug_samples

cd /home/postgres/fuzzing/fuzz_root

cp /home/postgres/src/afl-fuzz ./

printf "\n\n\n\nStart fuzzing. \n\n\n\n\n"

python3 run_parallel.py -o /home/postgres/fuzzing/fuzz_root/outputs $@

EOF
)

su -c "$SCRIPT_EXEC" postgres

echo "Finished\n"
