SET sql_mode = 'NO_ENGINE_SUBSTITUTION';
create table t1 (i int) engine=myisam max_rows=100000000000;
show create table t1;
alter table t1 max_rows=100;
show create table t1;
alter table t1 max_rows=100000000000;
show create table t1;
drop table t1;
CREATE TABLE t3(c1 DATETIME NOT NULL) ENGINE=MYISAM;
INSERT INTO t3 VALUES (0);
SET sql_mode = TRADITIONAL;
ALTER TABLE t3 ADD INDEX(c1);
SET sql_mode = '';
DROP TABLE t3;