CREATE TABLE t1(i INT) ENGINE MYISAM DATA DIRECTORY "/data/yu/Squirrel_DBMS_Fuzzing/MySQL_source/mysql-server-inst/bld/mysql-test/var/tmp/export";
INSERT INTO t1 VALUES (0), (2), (4);
DROP TABLE t1;
IMPORT TABLE FROM 't1_*.sdi';
SELECT * FROM t1 ORDER BY i;
DROP TABLE t1;
