drop database if exists mysqltest_db1;
create database mysqltest_db1;
use mysqltest_db1;
create table t_column_priv_only (a int, b int);
create table t_select_priv like t_column_priv_only;
create table t_no_priv like t_column_priv_only;
insert into mysqltest_db1.t_column_priv_only (a) VALUES (1);
select column_name as 'Field',column_type as 'Type',is_nullable as 'Null',column_key as 'Key',column_default as 'Default',extra as 'Extra' from information_schema.columns where table_schema='mysqltest_db1' and table_name='t_column_priv_only';
show columns from mysqltest_db1.t_column_priv_only;
show columns from mysqltest_db1.t_no_priv;
select column_name as 'Field',column_type as 'Type',is_nullable as 'Null',column_key as 'Key',column_default as 'Default',extra as 'Extra' from information_schema.columns where table_schema='mysqltest_db1' and table_name='t_no_priv';
create table test.t_no_priv like mysqltest_db1.column_priv_only;
select * from mysqltest_db1.t_column_priv_only;
show create table mysqltest_db1.t_column_priv_only;
show columns from mysqltest_db1.t_select_priv;
drop table if exists test.t_duplicated;
create table test.t_duplicated like mysqltest_db1.t_select_priv;
drop table test.t_duplicated;
show create table mysqltest_db1.t_select_priv;
show create table mysqltest_db1.t_no_priv;
use mysqltest_db1;
CREATE TABLE t5 (s1 INT);
CREATE INDEX i ON t5 (s1);
CREATE TABLE t6 (s1 INT, s2 INT);
CREATE VIEW v5 AS SELECT * FROM t5;
CREATE VIEW v6 AS SELECT * FROM t6;
CREATE VIEW v2 AS SELECT * FROM t_select_priv;
CREATE VIEW v3 AS SELECT * FROM t_select_priv;
CREATE INDEX i ON t6 (s1);
ANALYZE TABLE t6;
use mysqltest_db1;
SELECT * FROM INFORMATION_SCHEMA.STATISTICS WHERE table_name='t5';
SHOW INDEX FROM t5;
SHOW INDEX FROM t6;
CHECK TABLE t6;
CHECK TABLE t5;
CHECKSUM TABLE t6;
CHECKSUM TABLE t_select_priv;
SHOW CREATE VIEW v5;
SHOW CREATE VIEW v6;
SHOW CREATE VIEW v2;
SHOW CREATE VIEW v3;
drop database mysqltest_db1;
USE test;
CREATE ROLE r1,r2,r3;
GRANT r3 TO r2;
CREATE USER''@''IDENTIFIED WITH 'server' AS 'user';
CREATE USER plug IDENTIFIED WITH 'server';
FLUSH PRIVILEGES;
CREATE ROLE testrole;
GRANT abc ON *.* TO testrole;
REVOKE abc ON *.* FROM testrole;
DROP USER testrole;
CREATE USER ''@'';
GRANT EXECUTE ON PROCEDURE sys.table_exists TO ''@'';
GRANT SELECT ON db1.* TO ''@'';
SHOW GRANTS FOR ''@'';
DROP USER ''@'';
