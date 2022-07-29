CREATE TABLE t1 ( c1 int(10) unsigned NOT NULL AUTO_INCREMENT, c2 varchar(30) NOT NULL, c3 smallint(5) unsigned DEFAULT NULL, PRIMARY KEY (c1)) ENGINE = archive DATA DIRECTORY = '/data/yu/Squirrel_DBMS_Fuzzing/MySQL_source/mysql-server-inst/bld/mysql-test/var/tmp/archive' INDEX DIRECTORY = '/data/yu/Squirrel_DBMS_Fuzzing/MySQL_source/mysql-server-inst/bld/mysql-test/var/tmp/archive';
INSERT INTO t1 VALUES (NULL, "first", 1);
INSERT INTO t1 VALUES (NULL, "second", 2);
INSERT INTO t1 VALUES (NULL, "third", 3);
SHOW CREATE TABLE t1;
DROP TABLE t1;
