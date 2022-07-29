FROM ubuntu:20.04 AS sqlright_mysql_tools
MAINTAINER "PSU-Security-Universe"

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN chmod 777 /tmp

RUN apt -y update
RUN apt -y upgrade
RUN apt -y update
RUN apt -y install bison
RUN apt -y install build-essential
RUN apt -y install clang
RUN apt -y install cmake
RUN apt -y install flex
RUN apt -y install g++-multilib
RUN apt -y install gcc-multilib
RUN apt -y install gdb
RUN apt -y install git
RUN apt -y install libncurses5-dev
RUN apt -y install libreadline-dev
RUN apt -y install libssl-dev
RUN apt -y install make
RUN apt -y install pkg-config
RUN apt -y install python3
RUN apt -y install python3-pip
RUN apt -y install tmux
RUN apt -y install vim
RUN apt -y install xinetd
RUN apt -y install zlib1g-dev 
RUN apt -y install screen
RUN apt -y install watch
RUN apt -y install unzip
RUN pip install libtmux
RUN apt -y install wget

RUN apt -y install llvm
RUN apt -y install clang

RUN apt -y install g++-9
RUN apt -y install gcc-9

RUN apt -y install libnuma-dev


# Install mysql-client related libraries, for the compilation of sqlright.
RUN pip3 install psutil
RUN pip3 install mysql-connector-python mysql-connector-python
RUN apt -y install libmysqlclient-dev
RUN pip3 install mysqlclient

RUN useradd -ms /bin/bash mysql

ENV CC=clang
ENV CXX=clang++

RUN chown -R mysql:mysql /home/mysql

# build block-coverage AFL
WORKDIR /home/mysql
COPY AFL /home/mysql/AFL
RUN chown -R mysql:mysql /home/mysql

USER mysql
WORKDIR /home/mysql/AFL 
RUN make
WORKDIR /home/mysql/AFL/llvm_mode
# ENV LLVM_CONFIG=llvm-config-6.0
RUN make 

# ---------------------------------------------------------------------------------------------------------------
FROM sqlright_mysql_tools AS sqlright_mysql_source_build

# build MySQL instrumented by afl-clang-fast
USER mysql
WORKDIR /home/mysql/
RUN wget https://github.com/mysql/mysql-server/archive/refs/tags/mysql-8.0.27.zip
RUN unzip mysql-8.0.27.zip
RUN mv mysql-server-mysql-8.0.27 mysql-server
WORKDIR /home/mysql/mysql-server
# MySQL version 8.0.27
# RUN git checkout 3290a66c89eb1625a7058e0ef732432b6952b435 
RUN mkdir bld
WORKDIR /home/mysql/mysql-server/bld
ENV CC=/home/mysql/AFL/afl-clang-fast
ENV CXX=/home/mysql/AFL/afl-clang-fast++
RUN cmake .. -DDOWNLOAD_BOOST=1 -DWITH_BOOST=../boost -DWITH_UNIT_TESTS=OFF -DUSE_LD_GOLD=1
RUN make -j$(nproc)

# Recover the original compiler. 
ENV CC=gcc-9
ENV CXX=g++-9


# ---------------------------------------------------------------------------------------------------------------
FROM sqlright_mysql_source_build AS sqlright_src

# Install SQLRight MySQL
USER root
COPY src /home/mysql/src
WORKDIR /home/mysql/src/parser
RUN wget https://github.com/mysql/mysql-server/archive/refs/tags/mysql-8.0.27.zip
RUN unzip mysql-8.0.27.zip 
RUN mv mysql-server-mysql-8.0.27 mysql-server
RUN chown -R mysql:mysql /home/mysql/src

# Add SQLRight modification to the MySQL source code.
USER mysql
WORKDIR /home/mysql/src/parser/patches
RUN bash ./replace-changed-code.sh

# Compile the build-in MySQL source code.
WORKDIR /home/mysql/src/parser/mysql-server
RUN mkdir bld
WORKDIR /home/mysql/src/parser/mysql-server/bld

# Mute the Warning information. The modified version of the MySQL does return many Warnings while compiling. Known problem, ignore them. 
RUN cmake .. -DDOWNLOAD_BOOST=1 -DWITH_BOOST=../boost 
RUN make -j$(nproc)

WORKDIR /home/mysql/src
RUN make

USER root
RUN cp /home/mysql/src/parser/mysql-server/bld/library_output_directory/libserver_unittest_library.so /usr/lib/


# Setup other SQLRight configurations.

# Final setup. Setup all the remaining fuzzing settings.
FROM sqlright_src

# Finished setup the SQLRight source code.

# Copy all the required helper script to the container.
USER root
COPY scripts /home/mysql/scripts
RUN chown -R mysql:mysql /home/mysql/scripts

# set up fuzzing
USER root
COPY fuzz_root /home/mysql/fuzzing/fuzz_root
RUN chown -R mysql:mysql /home/mysql/fuzzing/

# Not sure why, but user MySQL doesn't have the permission to open the database.
USER root
RUN chown -R mysql:mysql /home/mysql/mysql-server/bld/bin
RUN chown -R mysql:mysql /home/mysql/mysql-server/bld/library_output_directory
RUN chown mysql:mysql /home/mysql/mysql-server/bld
RUN chown -R mysql:mysql /var
RUN chown -R mysql:mysql /tmp

# set up MySQL database
USER mysql
WORKDIR /home/mysql/mysql-server/bld/
RUN mkdir data
RUN bin/mysqld --initialize-insecure --user=mysql --datadir=data
RUN bin/mysql_ssl_rsa_setup --datadir=data
RUN mkdir data_all
RUN mv data data_all/ori_data

# Further setup the database info
USER mysql
WORKDIR /home/mysql/scripts
RUN python3 setup_database.py


USER root
WORKDIR /home/mysql/fuzzing/fuzz_root

#ENTRYPOINT ../afl-fuzz -t 2000 -m 2000 -i ./crashes -o ../output /usr/local/pgsql/bin/postgres --single -D /usr/local/pgsql/data main 
