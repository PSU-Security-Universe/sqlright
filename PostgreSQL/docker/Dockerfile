FROM ubuntu:20.04
MAINTAINER "PSU-Security-Universe"

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN chmod 777 /tmp

RUN apt -y update
RUN apt -y upgrade
RUN apt -y install bison 
RUN apt -y install flex 
RUN apt -y install git 
RUN apt -y install make 
RUN apt -y install cmake 
RUN apt -y install build-essential 
RUN apt -y install gcc-multilib 
RUN apt -y install g++-multilib 
RUN apt -y install clang
RUN apt -y install xinetd 
RUN apt -y install libreadline-dev 
RUN apt -y install zlib1g-dev 
RUN apt -y install gdb 
RUN apt -y install vim 
RUN apt -y install tmux 
RUN apt -y install python3
RUN apt -y install python3-pip
RUN apt -y install libxml2-dev 
RUN apt -y install libxslt-dev 
RUN apt -y install libssl-dev 
RUN apt -y install libxml2-utils 
RUN apt -y install xsltproc
RUN apt install -y libpq-dev
RUN apt -y install screen
RUN apt -y install watch
RUN apt -y install unzip
RUN apt -y install wget

RUN apt -y install llvm
RUN apt -y install clang

RUN apt install -y g++-9
RUN apt install -y gcc-9


RUN useradd -ms /bin/bash postgres
USER postgres

RUN pip3 install libtmux

WORKDIR /home/postgres

# Build AFL. 
RUN git clone https://github.com/google/AFL.git

WORKDIR /home/postgres/AFL
RUN sed -i  's/#define MAP_SIZE_POW2       16/#define MAP_SIZE_POW2       18/' config.h
RUN make
WORKDIR /home/postgres/AFL/llvm_mode
# ENV LLVM_CONFIG=llvm-config-6.0
RUN make

# Build Postgres REL_14_0

WORKDIR /home/postgres
RUN git clone https://github.com/postgres/postgres.git
RUN cp -r /home/postgres/postgres/ /home/postgres/postgres_ori/

WORKDIR /home/postgres/postgres/ 
RUN git checkout REL_14_0
RUN mkdir /home/postgres/postgres/bld

USER postgres
WORKDIR /home/postgres/postgres/bld
ENV CXX=/home/postgres/AFL/afl-clang-fast++
ENV CC=/home/postgres/AFL/afl-clang-fast
RUN ../configure --enable-debug --prefix=$(pwd) --exec-prefix=$(pwd) --enable-cassert && make -j$(nproc) && make install

WORKDIR /home/postgres/postgres_ori/
RUN git checkout REL_14_0
RUN mkdir -p /home/postgres/postgres_ori/bld

WORKDIR /home/postgres/postgres_ori/bld
ENV CXX=g++-9
ENV CC=gcc-9
RUN ../configure --enable-debug --prefix=$(pwd) --exec-prefix=$(pwd) && make -j$(nproc) && make install

# Setup Postgres. 
# RUN ./bin/initdb -D ./data
# RUN ./bin/pg_ctl -D ./data start 
# RUN ./bin/createdb x
# RUN ./bin/pg_ctl -D ./data stop
# RUN mkdir -p data_all
# RUN mv data data_all/ori_data 


ENV CXX=g++-9
ENV CC=gcc-9

# Install SQLRight Postgres
USER root
COPY src /home/postgres/src
RUN chown -R postgres:postgres /home/postgres/src

# Compile SQLRight postgres.
USER postgres
WORKDIR /home/postgres/src
RUN make -j$(nproc)

## Finished setup of the SQLRight Validity Configurations.

# Setup the fuzzing context.
RUN mkdir /home/postgres/fuzzing/
RUN mkdir /home/postgres/fuzzing/fuzz_root
RUN mkdir /home/postgres/fuzzing/fuzz_root/outputs
# COPY afl-fuzz /home/postgres/fuzzing/afl-fuzz
COPY fuzz_root/postgres_initlib /home/postgres/fuzzing/fuzz_root/postgres_initlib/
COPY fuzz_root/safe_generate_type /home/postgres/fuzzing/fuzz_root/
COPY fuzz_root/global_data_lib /home/postgres/fuzzing/fuzz_root/
COPY fuzz_root/inputs /home/postgres/fuzzing/fuzz_root/inputs
COPY fuzz_root/run_parallel.py /home/postgres/fuzzing/fuzz_root/
RUN mkdir /home/postgres/fuzzing/Bug_Analysis
RUN mkdir /home/postgres/fuzzing/Bug_Analysis/bug_samples


USER root
RUN chown -R postgres:postgres /home/postgres/fuzzing/

# At last, setup the Docker run script
USER root
COPY scripts /home/postgres/scripts
RUN chown -R postgres:postgres /home/postgres/scripts

#ENTRYPOINT ../afl-fuzz -t 2000 -m 2000 -i ./crashes -o ../output /usr/local/pgsql/bin/postgres --single -D /usr/local/pgsql/data main 

USER root
WORKDIR /home/postgres/fuzzing/

