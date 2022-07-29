CREATE TABLE t1 (i1 int, i2 int, c1 VARCHAR(256), c2 VARCHAR(256));
INSERT INTO t1 VALUES (101, 202, '-r-', '=raker=');
LOAD DATA INFILE '/data/yu/Squirrel_DBMS_Fuzzing/MySQL_source/mysql-server-inst/bld/mysql-test/var/tmp/bug31663.txt' IGNORE INTO TABLE t2 FIELDS TERMINATED BY 'raker';
TRUNCATE t1;
SET NAMES utf8;
SET sql_mode='STRICT_ALL_TABLES';
