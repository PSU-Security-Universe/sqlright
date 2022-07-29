set optimizer_trace_max_mem_size=10000000,@@session.optimizer_trace="enabled=on";
create table t1(a int, b int);
insert into t1 (a) values(1),(2);
analyze table t1,t2;
with cte as (select t1.a) select (select * from cte) from t1;
alter table t11 add index(a);
show create view v1;
flush status;
