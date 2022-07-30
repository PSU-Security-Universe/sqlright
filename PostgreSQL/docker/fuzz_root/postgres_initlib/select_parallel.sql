begin isolation level repeatable read;
set parallel_setup_cost=0;
set parallel_tuple_cost=0;
set min_parallel_table_scan_size=0;
set max_parallel_workers_per_gather=4;
explain (costs off)  select round(avg(aa)), sum(aa) from a_star;
select round(avg(aa)), sum(aa) from a_star a1;
alter table c_star set (parallel_workers = 0);
alter table d_star set (parallel_workers = 0);
explain (costs off)  select round(avg(aa)), sum(aa) from a_star;
select round(avg(aa)), sum(aa) from a_star a2;
alter table a_star set (parallel_workers = 0);
alter table b_star set (parallel_workers = 0);
alter table e_star set (parallel_workers = 0);
alter table f_star set (parallel_workers = 0);
explain (costs off)  select round(avg(aa)), sum(aa) from a_star;
select round(avg(aa)), sum(aa) from a_star a3;
alter table a_star reset (parallel_workers);
alter table b_star reset (parallel_workers);
alter table c_star reset (parallel_workers);
alter table d_star reset (parallel_workers);
alter table e_star reset (parallel_workers);
alter table f_star reset (parallel_workers);
set enable_parallel_append to off;
explain (costs off)  select round(avg(aa)), sum(aa) from a_star;
select round(avg(aa)), sum(aa) from a_star a4;
reset enable_parallel_append;
select sp_test_func() order by 1;
create table part_pa_test(a int, b int) partition by range(a);
create table part_pa_test_p1 partition of part_pa_test for values from (minvalue) to (0);
create table part_pa_test_p2 partition of part_pa_test for values from (0) to (maxvalue);
explain (costs off)	select (select max((select pa1.b from part_pa_test pa1 where pa1.a = pa2.a)))	from part_pa_test pa2;
drop table part_pa_test;
set parallel_leader_participation = off;
explain (costs off)  select count(*) from tenk1 where stringu1 = 'GRAAAA';
select count(*) from tenk1 where stringu1 = 'GRAAAA';
set max_parallel_workers = 0;
explain (costs off)  select count(*) from tenk1 where stringu1 = 'GRAAAA';
select count(*) from tenk1 where stringu1 = 'GRAAAA';
reset max_parallel_workers;
reset parallel_leader_participation;
alter table tenk1 set (parallel_workers = 4);
explain (verbose, costs off)select sp_parallel_restricted(unique1) from tenk1  where stringu1 = 'GRAAAA' order by 1;
explain (costs off)	select length(stringu1) from tenk1 group by length(stringu1);
select length(stringu1) from tenk1 group by length(stringu1);
explain (costs off)	select stringu1, count(*) from tenk1 group by stringu1 order by stringu1;
explain (costs off)	select  sum(sp_parallel_restricted(unique1)) from tenk1	group by(sp_parallel_restricted(unique1));
prepare tenk1_count(integer) As select  count((unique1)) from tenk1 where hundred >  1;
explain (costs off) execute tenk1_count(1);
execute tenk1_count(1);
deallocate tenk1_count;
alter table tenk2 set (parallel_workers = 0);
explain (costs off)	select count(*) from tenk1 where (two, four) not in	(select hundred, thousand from tenk2 where thousand > 100);
select count(*) from tenk1 where (two, four) not in	(select hundred, thousand from tenk2 where thousand > 100);
explain (costs off)	select * from tenk1 where (unique1 + random())::integer not in	(select ten from tenk2);
alter table tenk2 reset (parallel_workers);
set enable_indexscan = off;
set enable_indexonlyscan = off;
set enable_bitmapscan = off;
alter table tenk2 set (parallel_workers = 2);
explain (costs off)	select count(*) from tenk1        where tenk1.unique1 = (Select max(tenk2.unique1) from tenk2);
select count(*) from tenk1    where tenk1.unique1 = (Select max(tenk2.unique1) from tenk2);
reset enable_indexscan;
reset enable_indexonlyscan;
reset enable_bitmapscan;
alter table tenk2 reset (parallel_workers);
set enable_seqscan to off;
set enable_bitmapscan to off;
explain (costs off)	select  count((unique1)) from tenk1 where hundred > 1;
select  count((unique1)) from tenk1 where hundred > 1;
explain (costs off)	select  count(*) from tenk1 where thousand > 95;
select  count(*) from tenk1 where thousand > 95;
set enable_material = false;
explain (costs off)select * from  (select count(unique1) from tenk1 where hundred > 10) ss  right join (values (1),(2),(3)) v(x) on true;
select * from  (select count(unique1) from tenk1 where hundred > 10) ss  right join (values (1),(2),(3)) v(x) on true;
explain (costs off)select * from  (select count(*) from tenk1 where thousand > 99) ss  right join (values (1),(2),(3)) v(x) on true;
select * from  (select count(*) from tenk1 where thousand > 99) ss  right join (values (1),(2),(3)) v(x) on true;
reset enable_seqscan;
set enable_indexonlyscan to off;
set enable_indexscan to off;
alter table tenk1 set (parallel_workers = 0);
alter table tenk2 set (parallel_workers = 1);
explain (costs off)select count(*) from tenk1  left join (select tenk2.unique1 from tenk2 order by 1 limit 1000) ss  on tenk1.unique1 < ss.unique1 + 1  where tenk1.unique1 < 2;
select count(*) from tenk1  left join (select tenk2.unique1 from tenk2 order by 1 limit 1000) ss  on tenk1.unique1 < ss.unique1 + 1  where tenk1.unique1 < 2;
alter table tenk1 set (parallel_workers = 4);
alter table tenk2 reset (parallel_workers);
reset enable_material;
reset enable_bitmapscan;
reset enable_indexonlyscan;
reset enable_indexscan;
set enable_seqscan to off;
set enable_indexscan to off;
set enable_hashjoin to off;
set enable_mergejoin to off;
set enable_material to off;
set work_mem='64kB';
  explain (costs off)	select count(*) from tenk1, tenk2 where tenk1.hundred > 1 and tenk2.thousand=0;
  explain (costs off)	select count(*) from tenk1, tenk2 where tenk1.hundred > 1 and tenk2.thousand=0;
select count(*) from tenk1, tenk2 where tenk1.hundred > 1 and tenk2.thousand=0;
create table bmscantest (a int, t text);
insert into bmscantest select r, 'fooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo' FROM generate_series(1,100000) r;
create index i_bmtest ON bmscantest(a);
select count(*) from bmscantest where a>1;
reset enable_seqscan;
alter table tenk2 set (parallel_workers = 0);
explain (analyze, timing off, summary off, costs off)   select count(*) from tenk1, tenk2 where tenk1.hundred > 1        and tenk2.thousand=0;
alter table tenk2 reset (parallel_workers);
select * from explain_parallel_sort_stats();
reset enable_indexscan;
reset enable_hashjoin;
reset enable_mergejoin;
reset enable_material;
reset effective_io_concurrency;
drop table bmscantest;
drop function explain_parallel_sort_stats();
set enable_hashjoin to off;
set enable_nestloop to off;
explain (costs off)	select  count(*) from tenk1, tenk2 where tenk1.unique1 = tenk2.unique1;
select  count(*) from tenk1, tenk2 where tenk1.unique1 = tenk2.unique1;
reset enable_hashjoin;
reset enable_nestloop;
set enable_hashagg = false;
explain (costs off)   select count(*) from tenk1 group by twenty;
select count(*) from tenk1 group by twenty;
end;
explain (costs off, verbose)    select ten, sp_simple_func(ten) from tenk1 where ten < 100 order by ten;
drop function sp_simple_func(integer);
explain (costs off)   select count(*), generate_series(1,2) from tenk1 group by twenty;
select count(*), generate_series(1,2) from tenk1 group by twenty;
set parallel_leader_participation = off;
explain (costs off)   select count(*) from tenk1 group by twenty;
select count(*) from tenk1 group by twenty;
reset parallel_leader_participation;
set enable_material = false;
explain (costs off)select * from  (select string4, count(unique2)   from tenk1 group by string4 order by string4) ss  right join (values (1),(2),(3)) v(x) on true;
select * from  (select string4, count(unique2)   from tenk1 group by string4 order by string4) ss  right join (values (1),(2),(3)) v(x) on true;
reset enable_material;
reset enable_hashagg;
explain (costs off)select avg(unique1::int8) from tenk1;
select avg(unique1::int8) from tenk1;
explain (costs off)  select fivethous from tenk1 order by fivethous limit 4;
select fivethous from tenk1 order by fivethous limit 4;
set max_parallel_workers = 0;
explain (costs off)   select string4 from tenk1 order by string4 limit 5;
select string4 from tenk1 order by string4 limit 5;
set parallel_leader_participation = off;
explain (costs off)   select string4 from tenk1 order by string4 limit 5;
select string4 from tenk1 order by string4 limit 5;
reset parallel_leader_participation;
reset max_parallel_workers;
SAVEPOINT settings;
SET LOCAL force_parallel_mode = 1;
explain (costs off)  select stringu1::int2 from tenk1 where unique1 = 1;
ROLLBACK TO SAVEPOINT settings;
SAVEPOINT settings;
SET LOCAL force_parallel_mode = 1;
SELECT make_record(x) FROM (SELECT generate_series(1, 5) x) ss ORDER BY x;
ROLLBACK TO SAVEPOINT settings;
DROP function make_record(n int);
drop role if exists regress_parallel_worker;
create role regress_parallel_worker;
set role regress_parallel_worker;
reset session authorization;
drop role regress_parallel_worker;
set force_parallel_mode = 1;
select count(*) from tenk1;
reset force_parallel_mode;
reset role;
explain (costs off, verbose)  select count(*) from tenk1 a where (unique1, two) in    (select unique1, row_number() over() from tenk1 b);
explain (costs off)  select * from tenk1 a where two in    (select two from tenk1 b where stringu1 like '%AAAA' limit 3);
SAVEPOINT settings;
SET LOCAL force_parallel_mode = 1;
EXPLAIN (analyze, timing off, summary off, costs off) SELECT * FROM tenk1;
ROLLBACK TO SAVEPOINT settings;
SAVEPOINT settings;
SET LOCAL force_parallel_mode = 1;
select (stringu1 || repeat('abcd', 5000))::int2 from tenk1 where unique1 = 1;
ROLLBACK TO SAVEPOINT settings;
SAVEPOINT settings;
SET LOCAL parallel_setup_cost = 10;
ROLLBACK TO SAVEPOINT settings;
EXPLAIN (COSTS OFF)SELECT unique1 FROM tenk1 WHERE fivethous =	(SELECT unique1 FROM tenk1 WHERE fivethous = 1 LIMIT 1)UNION ALLSELECT unique1 FROM tenk1 WHERE fivethous =	(SELECT unique2 FROM tenk1 WHERE fivethous = 1 LIMIT 1)ORDER BY 1;
CREATE TABLE fooarr(f1 text, f2 int[], f3 text);
INSERT INTO fooarr VALUES('1', ARRAY[1,2], 'one');
PREPARE pstmt(text, int[]) AS SELECT * FROM fooarr WHERE f1 =  1 AND f2 =  2;
EXPLAIN (COSTS OFF) EXECUTE pstmt('1', make_some_array(1,2));
EXECUTE pstmt('1', make_some_array(1,2));
DEALLOCATE pstmt;
CREATE VIEW tenk1_vw_sec WITH (security_barrier) AS SELECT * FROM tenk1;
EXPLAIN (COSTS OFF)SELECT 1 FROM tenk1_vw_sec  WHERE (SELECT sum(f1) FROM int4_tbl WHERE f1 < unique1) < 100;
rollback;