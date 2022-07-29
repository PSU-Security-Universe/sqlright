create table t1(a int);
insert into t1 values(1),(2);
explain format=json with qn(a) as (select 1 from t1 limit 2) select * from qn where qn.a=(select * from qn qn1 limit 1) ;
explain format=traditional with qn(a) as (select 1 from t1 limit 2) select * from qn where qn.a=(select * from qn qn1 limit 1) ;
explain format=json with qn as (select cast("x" as char(100)) as a from t1 limit 2) select (select * from qn) from qn, qn qn1;
explain format=traditional with qn as (select cast("x" as char(100)) as a from t1 limit 2) select (select * from qn) from qn, qn qn1;
explain format=json with recursive qn as (select cast("x" as char(100)) as a from dual union all select concat("x",qn.a) from qn,t1 where length(qn.a)<10) select * from qn;
explain format=traditional with recursive qn as (select cast("x" as char(100)) as a from dual union all select concat("x",qn.a) from qn,t1 where length(qn.a)<10) select * from qn;
drop table t1;
