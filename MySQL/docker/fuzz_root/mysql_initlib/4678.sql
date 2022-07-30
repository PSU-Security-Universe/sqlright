drop table if exists t1, t2;
create table t1 (a integer, b integer,c1 CHAR(10));
insert into t1 (a) values (1),(2);
truncate table t1;
select count(*) from t1;
insert into t1 values(1,2,"test");
select count(*) from t1;
delete from t1;
select * from t1;
drop table t1;
select count(*) from t1;
create temporary table t1 (n int);
insert into t1 values (1),(2),(3);
truncate table t1;
select * from t1;
drop table t1;
truncate non_existing_table;
create table t1 (a integer auto_increment primary key);
insert into t1 (a) values (NULL),(NULL);
truncate table t1;
insert into t1 (a) values (NULL),(NULL);
SELECT * from t1;
delete from t1;
insert into t1 (a) values (NULL),(NULL);
SELECT * from t1;
drop table t1;
create temporary table t1 (a integer auto_increment primary key);
insert into t1 (a) values (NULL),(NULL);
truncate table t1;
insert into t1 (a) values (NULL),(NULL);
SELECT * from t1;
delete from t1;
insert into t1 (a) values (NULL),(NULL);
SELECT * from t1;
drop table t1;
create table t1 (s1 int);
insert into t1 (s1) values (1), (2), (3), (4), (5);
create view v1 as select * from t1;
truncate table v1;
drop view v1;
drop table t1;
CREATE TABLE t1 (c1 INT);
LOCK TABLE t1 WRITE;
INSERT INTO t1 VALUES (1);
SELECT * FROM t1;
TRUNCATE TABLE t1;
SELECT * FROM t1;
UNLOCK TABLES;
LOCK TABLE t1 READ;
TRUNCATE TABLE t1;
UNLOCK TABLES;
CREATE TABLE t2 (c1 INT);
LOCK TABLE t2 WRITE;
TRUNCATE TABLE t1;
UNLOCK TABLES;
CREATE VIEW v1 AS SELECT t1.c1 FROM t1,t2 WHERE t1.c1 = t2.c1;
INSERT INTO t1 VALUES (1), (2), (3);
INSERT INTO t2 VALUES (1), (3), (4);
SELECT * FROM v1;
TRUNCATE v1;
SELECT * FROM v1;
LOCK TABLE t1 WRITE;
SELECT * FROM v1;
TRUNCATE v1;
SELECT * FROM v1;
UNLOCK TABLES;
LOCK TABLE t1 WRITE, t2 WRITE;
SELECT * FROM v1;
TRUNCATE v1;
SELECT * FROM v1;
UNLOCK TABLES;
LOCK TABLE v1 WRITE;
SELECT * FROM v1;
TRUNCATE v1;
SELECT * FROM v1;
UNLOCK TABLES;
LOCK TABLE t1 WRITE, t2 WRITE, v1 WRITE;
SELECT * FROM v1;
TRUNCATE v1;
SELECT * FROM v1;
UNLOCK TABLES;
DROP VIEW v1;
DROP TABLE t1, t2;
CREATE PROCEDURE p1() SET @a = 5;
TRUNCATE p1;
SHOW CREATE PROCEDURE p1;
DROP PROCEDURE p1;
DROP TABLE IF EXISTS t1;
CREATE TABLE t1 AS SELECT 1 AS f1;
HANDLER t1 OPEN;
TRUNCATE t1;
HANDLER t1 READ FIRST;
DROP TABLE t1;
CREATE TABLE t1(a INT);
CREATE SCHEMA s1;
CREATE VIEW s1.v1 AS SELECT * FROM t1;
LOCK TABLE s1.v1 WRITE;
TRUNCATE TABLE t1;
UNLOCK TABLES;
DROP VIEW s1.v1;
DROP TABLE t1;
DROP SCHEMA s1;
CREATE TABLE t1(a INT, b TEXT, KEY (a)) SECONDARY_ENGINE=MOCK;
LOCK TABLES t1 WRITE;
TRUNCATE TABLE t1;
SELECT * FROM t1;
UNLOCK TABLES;
DROP TABLE t1;