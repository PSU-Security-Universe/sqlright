CREATE TABLE t1 (a int not null, b char (10) not null);
insert into t1 values(1,'a'),(2,'b'),(3,'c'),(3,'c');
analyze table t1;
(select a,b from t1 limit 2)  union all (select a,b from t2 order by a) limit 4;
create table t3 select a,b from t1 union select a from t2;
replace into t3 select a,b as c from t1 union all select a,b from t2;
(SELECT 1) UNION (SELECT 2) ORDER BY (SELECT a);
set SQL_SELECT_LIMIT=2;
INSERT INTO t1 VALUES (8,'dummy');
