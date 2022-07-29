FROM ubuntu:20.04 AS sqlright_mysql_tools
MAINTAINER "PSU-Security-Universe"

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN chmod 777 /tmp

RUN apt -y update
RUN apt -y upgrade
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
RUN pip3 install gitpython
RUN pip3 install loguru
RUN pip3 install rich

RUN apt -y install llvm
RUN apt -y install clang

RUN apt -y install g++-9
RUN apt -y install gcc-9

RUN apt -y install libsasl2-dev

RUN apt -y install libnuma-dev


# Install mysql-client related libraries, for the compilation of sqlright.
RUN pip3 install psutil
RUN pip3 install mysql-connector-python mysql-connector-python
RUN apt -y install libmysqlclient-dev
RUN pip3 install mysqlclient

RUN useradd -ms /bin/bash mysql
RUN chown -R mysql:mysql /home/mysql

# Setup mysql git repo.
USER mysql

ENV CC=gcc-9
ENV CXX=g++-9

WORKDIR /home/mysql/
RUN git clone https://github.com/mysql/mysql-server.git
WORKDIR /home/mysql/mysql-server
RUN git checkout 8.0

# Copy the bisecting python script to the repo. 
FROM sqlright_mysql_tools AS bisecting_setup

USER root
RUN mkdir -p /home/mysql/bisecting
COPY bisecting_cache_binaries /home/mysql/bisecting/bisecting_cache_binaries 
RUN chown -R mysql:mysql /home/mysql/bisecting

USER mysql
WORKDIR /home/mysql/
RUN mkdir -p mysql_binary

USER root
WORKDIR /home/mysql
