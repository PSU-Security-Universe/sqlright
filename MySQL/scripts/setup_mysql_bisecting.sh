#!/bin/bash -e
cd "$(dirname "$0")"/../bisecting/bisecting

if [ ! -e ./mysql_binary_zip/mysql_binary.zip.001 ]; then
    
    echo "Error: The MySQL cached binaries not existed. Please download the MySQL cached binaries from the DockerHub: steveleungsly/sqlright_mysql_bisecting:version1.0. And place the binaries in the <sqlright_root>/MySQL/bisecting/bisecting/mysql_binary_zip folder. "
    echo "Aborted Docker build due to MySQL binary missing. "
    exit 1
fi

## For debug purpose, keep all intermediate steps to fast reproduce the run results.
#sudo docker build --rm=false -f ./Dockerfile -t sqlright_mysql_bisecting .  

## Release code. Remove all intermediate steps to save hard drive space.
sudo docker build --rm=true -f ./Dockerfile -t sqlright_mysql_bisecting .



