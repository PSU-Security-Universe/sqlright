#!/bin/bash -e

# This file is used for start the SQLRight MySQL bisecting inside the Docker env.
# entrypoint: bash

chown -R mysql:mysql /home/mysql/bisecting_scripts

SCRIPT_EXEC=$(cat << EOF

cd /home/mysql/bisecting_scripts

python3 analysis.py $@

EOF
)

su -c "$SCRIPT_EXEC" mysql

echo "Finished\n"
