#!/bin/bash -e
cd "$(dirname "$0")"/../bisecting/bisecting

#if [ ! -f "mysql_binary_zip.zip" ]; then 
#    cat ./mysql_binary_zip/mysql_binary_zip.zip* > ./mysql_binary_zip.zip
#    for i in $(seq 1 59);
#    do
#        if [[ "$i" -lt "10" ]]
#        then
#            command="cat ./mysql_binary_zip/mysql_binary_zip.zip.00$i"" > ./mysql_binary_zip.zip "
#            echo "Running command: $command"
#            bash -c "$command"
#        else
#            command="cat ./mysql_binary_zip/mysql_binary_zip.zip.0$i"" > ./mysql_binary_zip.zip "
#            echo "Running command: $command"
#            bash -c "$command"
#        fi
#    done
#fi

## For debug purpose, keep all intermediate steps to fast reproduce the run results.
#sudo docker build --rm=false -f ./Dockerfile -t sqlright_mysql_bisecting .  

## Release code. Remove all intermediate steps to save hard drive space.
sudo docker build --rm=true -f ./Dockerfile -t sqlright_mysql_bisecting .



