#!/bin/bash -e
cd "$(dirname "$0")"/../docker

if [ -e "./sqlite_bisecting_binary_zip/sqlite_bisecting_binary.zip.001" ]; then
    echo "Unzipping files. Please wait. "
    cd sqlite_bisecting_binary_zip
    cat sqlite_bisecting_binary.zip* > ./sqlite_bisecting_binary_zip.zip
    unzip sqlite_bisecting_binary_zip.zip &> /dev/null
    rm -rf ../sqlite_bisecting_binary
    mv sqlite_bisecting_binary ../sqlite_bisecting_binary
    cd ../
else
    echo "sqlite_bisecting_binary zip files not existed. Skip SQLite bisecting setup steps. "
fi

## For debug purpose, keep all intermediate steps to fast reproduce the run results.
#sudo docker build --rm=false -f ./Dockerfile -t sqlright_sqlite .

## Release code. Remove all intermediate steps to save hard drive space.
sudo docker build --rm=true -f ./Dockerfile -t sqlright_sqlite .
