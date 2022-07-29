FROM ubuntu:20.04 AS fundamental
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
RUN apt -y install tcl

RUN apt -y install llvm
RUN apt -y install clang

RUN apt install -y g++-9
RUN apt install -y gcc-9

RUN pip3 install gitpython

RUN useradd -ms /bin/bash sqlite
USER sqlite

RUN pip3 install libtmux

WORKDIR /home/sqlite

# Build AFL. 
RUN git clone https://github.com/google/AFL.git

WORKDIR /home/sqlite/AFL
RUN sed -i  's/#define MAP_SIZE_POW2       16/#define MAP_SIZE_POW2       18/' config.h
RUN make
WORKDIR /home/sqlite/AFL/llvm_mode
# ENV LLVM_CONFIG=llvm-config-6.0
RUN make

FROM fundamental AS sqlite3_build

# Build SQLite3
WORKDIR /home/sqlite
RUN git clone https://github.com/sqlite/sqlite.git
RUN cp -r sqlite sqlite_ori

## Build instrumented SQLite3
WORKDIR /home/sqlite/sqlite
RUN git checkout version-3.34.0
ENV CXX=/home/sqlite/AFL/afl-clang-fast++
ENV CC=/home/sqlite/AFL/afl-clang-fast
RUN ./configure --enable-debug --enable-fts5
RUN make -j$(nproc)

## Build uninstrumented SQLite3
WORKDIR /home/sqlite/sqlite_ori
RUN git checkout version-3.34.0
ENV CXX=g++-9
ENV CC=gcc-9
RUN ./configure --enable-debug --enable-fts5
RUN make -j$(nproc)

# Setup the SQLRight source code.
FROM sqlite3_build AS sqlright_build

USER root
WORKDIR /home/sqlite/src
COPY src /home/sqlite/src
RUN chown -R sqlite:sqlite /home/sqlite/src

USER sqlite
WORKDIR /home/sqlite/src
RUN make -j$(nproc)

# Setup the fuzzing context
FROM sqlright_build AS sqlite3_fuzzing
USER sqlite
WORKDIR /home/sqlite
RUN mkdir -p fuzzing

USER root
WORKDIR /home/sqlite/fuzzing
COPY fuzz_root /home/sqlite/fuzzing/fuzz_root
RUN chown -R sqlite:sqlite /home/sqlite/fuzzing/

USER sqlite
WORKDIR /home/sqlite/fuzzing
RUN mkdir -p Bug_Analysis

# Setup the SQLite bisecting environment
USER root
COPY bisecting /home/sqlite/bisecting
RUN chown -R sqlite:sqlite /home/sqlite/bisecting

# Setup the SQLite bisecting cached binaries. 
USER root
COPY sqlite_bisecting_binary /home/sqlite/sqlite_bisecting_binary
RUN chown -R sqlite:sqlite /home/sqlite/sqlite_bisecting_binary

# At last, setup the Docker helper scripts
USER root
WORKDIR /home/sqlite
COPY scripts /home/sqlite/scripts
RUN chown -R sqlite:sqlite /home/sqlite/scripts

# Entry workdir.
WORKDIR /home/sqlite/fuzzing/fuzz_root


