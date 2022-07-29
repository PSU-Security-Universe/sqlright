import libtmux
import re
import time
import os

server = libtmux.Server()
session = server.new_session(session_name="fuzzing")
create_database_window = session.new_window(attach=False, window_name="create_database")
pane = create_database_window.attached_pane

pane.send_keys("cd /home/mysql/mysql-server/bld")
pane.send_keys("./bin/mysqld --basedir=./ --datadir=./data_all/ori_data --log-error=./err.err --pid-file=./pid.pid &")
time.sleep(10)
create_database_window_client = session.new_window(attach=False, window_name="create_database_client")
pane_client = create_database_window_client.attached_pane
pane_client.send_keys("cd /home/mysql/mysql-server/bld")
pane_client.send_keys("./bin/mysql -u root -e \"create database if not exists test_sqlright1; create database if not exists test_init;\"")
time.sleep(5)
create_database_window.kill_window()
create_database_window_client.kill_window()
os.system("kill `pidof mysqld`")
