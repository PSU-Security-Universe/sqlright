#!/bin/bash -e
cd "$(dirname "$0")"/../docker

if [ ! -d ./sqlite_bisecting_binary ]; then
    if [ -f ./sqlite_bisecting_binary/sqlite_bisecting_binary.zip.001 ]; then
        cd sqlite_bisecting_binary_zip
        cat sqlite_bisecting_binary.zip* > ./sqlite_bisecting_binary_zip.zip
        echo "Unzipping files. Please wait. "
        unzip sqlite_bisecting_binary_zip.zip &> /dev/null
        mv sqlite_bisecting_binary ../sqlite_bisecting_binary
        cd ../
    fi
fi


## For debug purpose, keep all intermediate steps to fast reproduce the run results.
#sudo docker build --rm=false -f ./Dockerfile -t sqlright_sqlite .

## Release code. Remove all intermediate steps to save hard drive space.
sudo docker build --rm=true -f ./Dockerfile -t sqlright_sqlite .
