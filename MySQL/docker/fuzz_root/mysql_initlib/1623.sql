drop table if exists t1;
set @@sql_mode="ANSI";
select @@sql_mode;
SELECT 'A' || 'B';
CREATE TABLE t1 (id INT, id2 int);
SELECT id,NULL,1,1.1,'a' FROM t1 GROUP BY id;
SELECT id FROM t1 GROUP BY id2;
drop table t1;
SET @@SQL_MODE="";
