RESET MASTER;
SET GLOBAL GTID_MODE=OFF_PERMISSIVE;
CREATE TABLE t1(c1 INT PRIMARY KEY) ENGINE=MyISAM;
CREATE TABLE t1_c like t1;
CREATE INDEX t_index ON t1(c1);
CREATE TEMPORARY TABLE temp1(c1 INT) ENGINE=MyISAM;
ALTER TABLE temp1 ADD COLUMN other_column INT;
CREATE VIEW v1 as SELECT 1;
CREATE USER user1;
CREATE DATABASE db1;
INSERT INTO t1 VALUES (3);
INSERT INTO t1_c VALUES (1), (2);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:1';
CREATE TABLE t1(c1 INT, c2 INT);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:2';
ALTER TABLE t2 ADD COLUMN other_column INT;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:3';
DROP TABLE t2;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:4';
CREATE INDEX t_index ON t1(c1);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:5';
DROP INDEX t_index2 ON t1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:6';
RENAME TABLE t3 TO t4;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:7';
CREATE TEMPORARY TABLE temp1(c1 INT);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:8';
ALTER TABLE temp1 ADD COLUMN other_column INT;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:9';
DROP TEMPORARY TABLE temp2;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:10';
CREATE DATABASE db1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:12';
DROP DATABASE db2;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:18';
DROP VIEW v2;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:19';
CREATE VIEW v1 as SELECT 1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:20';
INSERT INTO t1 VALUES (3), (2);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:21';
INSERT INTO t1 SELECT * FROM t1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:22';
INSERT INTO t1 VALUES (2), (3);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:23';
INSERT INTO t1 SELECT * FROM t1_c;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:24';
UPDATE t1 SET c1=2 WHERE c1=1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:25';
UPDATE t1_c, t1 SET t1_c.c1=3, t1.c1=2 WHERE t1_c.c1=1 AND t1.c1=1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:26';
UPDATE t1, t1_c SET t1.c1=2, t1_c.c1=3 WHERE t1.c1=1 OR t1_c.c1=1;
SET GTID_NEXT = 'AUTOMATIC';
DROP INDEX t_index ON t1;
DROP TABLE t1, t1_c;
DROP TEMPORARY TABLE temp1;
DROP VIEW v1;
DROP USER user1;
SET GLOBAL GTID_MODE=OFF;
DROP DATABASE db1;
RESET MASTER;
SET GLOBAL GTID_MODE=OFF_PERMISSIVE;
CREATE TABLE t1(c1 INT PRIMARY KEY) ENGINE=InnoDB;
CREATE TABLE t1_c like t1;
CREATE INDEX t_index ON t1(c1);
CREATE TEMPORARY TABLE temp1(c1 INT) ENGINE=InnoDB;
ALTER TABLE temp1 ADD COLUMN other_column INT;
CREATE VIEW v1 as SELECT 1;
CREATE USER user1;
CREATE DATABASE db1;
INSERT INTO t1 VALUES (3), (4);
INSERT INTO t1_c VALUES (1), (2), (3);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:1';
CREATE TABLE t1(c1 INT, c2 INT);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:2';
ALTER TABLE t2 ADD COLUMN other_column INT;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:3';
DROP TABLE t2;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:4';
CREATE INDEX t_index ON t1(c1);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:5';
DROP INDEX t_index2 ON t1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:6';
RENAME TABLE t3 TO t4;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:7';
CREATE TEMPORARY TABLE temp1(c1 INT);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:8';
ALTER TABLE temp1 ADD COLUMN other_column INT;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:9';
DROP TEMPORARY TABLE temp2;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:10';
CREATE DATABASE db1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:12';
DROP DATABASE db2;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:18';
DROP VIEW v2;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:19';
CREATE VIEW v1 as SELECT 1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:20';
INSERT INTO t1 VALUES (3), (2);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:21';
INSERT INTO t1 SELECT * FROM t1;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:22';
INSERT INTO t1 VALUES (2), (3);
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:23';
INSERT INTO t1 SELECT * FROM t1_c;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:24';
UPDATE t1 SET c1=3 WHERE c1=4;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:25';
UPDATE t1_c, t1 SET t1_c.c1=6, t1.c1=3 WHERE t1_c.c1=1 AND t1.c1=4;
SET SESSION GTID_NEXT='6f9ecbae-6c04-11ec-a9aa-70b5e8ec31dc:26';
UPDATE t1, t1_c SET t1.c1=3, t1_c.c1=6 WHERE t1.c1=4 OR t1_c.c1=1;
SET GTID_NEXT = 'AUTOMATIC';
DROP INDEX t_index ON t1;
DROP TABLE t1, t1_c;
DROP TEMPORARY TABLE temp1;
DROP VIEW v1;
DROP USER user1;
SET GLOBAL GTID_MODE=OFF;
DROP DATABASE db1;
