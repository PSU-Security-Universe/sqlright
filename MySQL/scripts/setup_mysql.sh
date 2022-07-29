#!/bin/bash -e
cd "$(dirname "$0")"/../docker

## For debug purpose, keep all intermediate steps to fast reproduce the run results.
#sudo docker build --rm=false -f ./Dockerfile -t sqlright_mysql .  

## Release code. Remove all intermediate steps to save hard drive space.
sudo docker build --rm=true -f ./Dockerfile -t sqlright_mysql .



