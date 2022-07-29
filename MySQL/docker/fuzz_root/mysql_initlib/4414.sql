set optimizer_switch='semijoin=on,materialization=on,firstmatch=on,loosescan=on,index_condition_pushdown=on,mrr=on';
set @old_opt_switch=@@optimizer_switch;
set optimizer_switch='subquery_materialization_cost_based=off';
SET sql_mode = 'NO_ENGINE_SUBSTITUTION';
drop table if exists t1, t2, t3, t1i, t2i, t3i;
drop view if exists v1, v2, v1m, v2m;
create table t1 (a1 char(8), a2 char(8)) charset utf8mb4;
create table t2 (b1 char(8), b2 char(8)) charset utf8mb4;
create table t3 (c1 char(8), c2 char(8)) charset utf8mb4;
insert into t1 values ('1 - 00', '2 - 00');
insert into t1 values ('1 - 01', '2 - 01');
insert into t1 values ('1 - 02', '2 - 02');
insert into t2 values ('1 - 01', '2 - 01');
insert into t2 values ('1 - 01', '2 - 01');
insert into t2 values ('1 - 02', '2 - 02');
insert into t2 values ('1 - 02', '2 - 02');
insert into t2 values ('1 - 03', '2 - 03');
insert into t3 values ('1 - 01', '2 - 01');
insert into t3 values ('1 - 02', '2 - 02');
insert into t3 values ('1 - 03', '2 - 03');
insert into t3 values ('1 - 04', '2 - 04');
ANALYZE TABLE t1, t2, t3;
create table t1i (a1 char(8), a2 char(8)) charset utf8mb4;
create table t2i (b1 char(8), b2 char(8)) charset utf8mb4;
create table t3i (c1 char(8), c2 char(8)) charset utf8mb4;
create index it1i1 on t1i (a1);
create index it1i2 on t1i (a2);
create index it1i3 on t1i (a1, a2);
create index it2i1 on t2i (b1);
create index it2i2 on t2i (b2);
create index it2i3 on t2i (b1, b2);
create index it3i1 on t3i (c1);
create index it3i2 on t3i (c2);
create index it3i3 on t3i (c1, c2);
insert into t1i select * from t1;
insert into t2i select * from t2;
insert into t3i select * from t3;
ANALYZE TABLE t1i, t2i, t3i;
/****************************************************************************** * Simple tests. ******************************************************************************/ # non-indexed nullable fields explain select * from t1 where a1 in (select b1 from t2 where b1 > '0');
select * from t1 where a1 in (select b1 from t2 where b1 > '0');
explain select * from t1 where a1 in (select b1 from t2 where b1 > '0' group by b1);
select * from t1 where a1 in (select b1 from t2 where b1 > '0' group by b1);
explain select * from t1 where (a1, a2) in (select b1, b2 from t2 where b1 > '0' group by b1, b2);
select * from t1 where (a1, a2) in (select b1, b2 from t2 where b1 > '0' group by b1, b2);
explain select * from t1 where (a1, a2) in (select b1, min(b2) from t2 where b1 > '0' group by b1);
select * from t1 where (a1, a2) in (select b1, min(b2) from t2 where b1 > '0' group by b1);
explain select * from t1i where a1 in (select b1 from t2i where b1 > '0');
select * from t1i where a1 in (select b1 from t2i where b1 > '0');
explain select * from t1i where a1 in (select b1 from t2i where b1 > '0' group by b1);
select * from t1i where a1 in (select b1 from t2i where b1 > '0' group by b1);
explain select * from t1i where (a1, a2) in (select b1, b2 from t2i where b1 > '0');
select * from t1i where (a1, a2) in (select b1, b2 from t2i where b1 > '0');
explain select * from t1i where (a1, a2) in (select b1, b2 from t2i where b1 > '0' group by b1, b2);
select * from t1i where (a1, a2) in (select b1, b2 from t2i where b1 > '0' group by b1, b2);
explain select * from t1i where (a1, a2) in (select b1, min(b2) from t2i where b1 > '0' group by b1);
select * from t1i where (a1, a2) in (select b1, min(b2) from t2i where b1 > '0' group by b1);
explain select * from t1 where (a1, a2) in (select b1, max(b2) from t2i group by b1);
select * from t1 where (a1, a2) in (select b1, max(b2) from t2i group by b1);
prepare st1 from "explain select * from t1 where (a1, a2) in (select b1, max(b2) from t2i group by b1)";
execute st1;
execute st1;
prepare st2 from "select * from t1 where (a1, a2) in (select b1, max(b2) from t2i group by b1)";
execute st2;
execute st2;
explain select * from t1 where (a1, a2) in (select b1, min(b2) from t2i where b1 > '0' group by b1);
select * from t1 where (a1, a2) in (select b1, min(b2) from t2i where b1 > '0' group by b1);
select * from t1 where (a1, a2) in (select b1, min(b2) from t2i limit 1,1);
explain select * from t1 where (a1, a2) in (select b1, b2 from t2 order by b1, b2);
select * from t1 where (a1, a2) in (select b1, b2 from t2 order by b1, b2);
explain select * from t1i where (a1, a2) in (select b1, b2 from t2i order by b1, b2);
select * from t1i where (a1, a2) in (select b1, b2 from t2i order by b1, b2);
set @previous_sql_mode_htnt542nh=@@sql_mode;
set sql_mode=(select replace(@@sql_mode,'ONLY_FULL_GROUP_BY',''));
create algorithm=merge view v1 as select b1, c2 from t2, t3 where b2 > c2;
create algorithm=merge view v2 as select b1, c2 from t2, t3 group by b2, c2;
create algorithm=temptable view v1m as select b1, c2 from t2, t3 where b2 > c2;
create algorithm=temptable view v2m as select b1, c2 from t2, t3 group by b2, c2;
select * from v1 where (c2, b1) in (select c2, b1 from v2 where b1 is not null);
select * from v1 where (c2, b1) in (select distinct c2, b1 from v2 where b1 is not null);
select * from v1m where (c2, b1) in (select c2, b1 from v2m where b1 is not null);
select * from v1m where (c2, b1) in (select distinct c2, b1 from v2m where b1 is not null);
set @@sql_mode=@previous_sql_mode_htnt542nh;
drop view v1, v2, v1m, v2m;
explain select * from t1 where (a1, a2) in (select b1, b2 from t2 where b1 >  '0') and (a1, a2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
select * from t1 where (a1, a2) in (select b1, b2 from t2 where b1 >  '0') and (a1, a2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
explain select * from t1i where (a1, a2) in (select b1, b2 from t2i where b1 >  '0') and (a1, a2) in (select c1, c2 from t3i where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
select * from t1i where (a1, a2) in (select b1, b2 from t2i where b1 >  '0') and (a1, a2) in (select c1, c2 from t3i where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
explain select * from t1 where (a1, a2) in (select b1, b2 from t2 where b2 in (select c2 from t3 where c2 LIKE '%02') or b2 in (select c2 from t3 where c2 LIKE '%03')) and (a1, a2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
select * from t1 where (a1, a2) in (select b1, b2 from t2 where b2 in (select c2 from t3 where c2 LIKE '%02') or b2 in (select c2 from t3 where c2 LIKE '%03')) and (a1, a2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
explain select * from t1 where (a1, a2) in (select b1, b2 from t2 where b2 in (select c2 from t3 t3a where c1 = a1) or b2 in (select c2 from t3 t3b where c2 LIKE '%03')) and (a1, a2) in (select c1, c2 from t3 t3c where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
select * from t1 where (a1, a2) in (select b1, b2 from t2 where b2 in (select c2 from t3 t3a where c1 = a1) or b2 in (select c2 from t3 t3b where c2 LIKE '%03')) and (a1, a2) in (select c1, c2 from t3 t3c where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
explain (select * from t1 where (a1, a2) in (select b1, b2 from t2 where b2 in (select c2 from t3 where c2 LIKE '%02') or b2 in (select c2 from t3 where c2 LIKE '%03') group by b1, b2) and (a1, a2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0'))) UNION (select * from t1i where (a1, a2) in (select b1, b2 from t2i where b1 >  '0') and (a1, a2) in (select c1, c2 from t3i where (c1, c2) in (select b1, b2 from t2i where b2 > '0')));
(select * from t1 where (a1, a2) in (select b1, b2 from t2 where b2 in (select c2 from t3 where c2 LIKE '%02') or b2 in (select c2 from t3 where c2 LIKE '%03') group by b1, b2) and (a1, a2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0'))) UNION (select * from t1i where (a1, a2) in (select b1, b2 from t2i where b1 >  '0') and (a1, a2) in (select c1, c2 from t3i where (c1, c2) in (select b1, b2 from t2i where b2 > '0')));
explain select * from t1 where (a1, a2) in (select * from t1 where a1 > '0' UNION select * from t2 where b1 < '9') and (a1, a2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
select * from t1 where (a1, a2) in (select * from t1 where a1 > '0' UNION select * from t2 where b1 < '9') and (a1, a2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0'));
explain select * from t1, t3 where (a1, a2) in (select * from t1 where a1 > '0' UNION select * from t2 where b1 < '9') and (c1, c2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0')) and a1 = c1;
select * from t1, t3 where (a1, a2) in (select * from t1 where a1 > '0' UNION select * from t2 where b1 < '9') and (c1, c2) in (select c1, c2 from t3 where (c1, c2) in (select b1, b2 from t2i where b2 > '0')) and a1 = c1;
/****************************************************************************** * Negative tests, where materialization should not be applied. ******************************************************************************/ # UNION in a subquery explain select * from t3 where c1 in (select a1 from t1 where a1 > '0' UNION select b1 from t2 where b1 < '9');
select * from t3 where c1 in (select a1 from t1 where a1 > '0' UNION select b1 from t2 where b1 < '9');
explain select * from t1 where (a1, a2) in (select b1, b2 from t2 where b2 in (select c2 from t3 t3a where c1 = a1) or b2 in (select c2 from t3 t3b where c2 LIKE '%03')) and (a1, a2) in (select c1, c2 from t3 t3c where (c1, c2) in (select b1, b2 from t2i where b2 > '0' or b2 = a2));
explain select * from t1 where (a1, a2) in (select '1 - 01', '2 - 01');
select * from t1 where (a1, a2) in (select '1 - 01', '2 - 01');
explain select * from t1 where (a1, a2) in (select '1 - 01', '2 - 01' from dual);
select * from t1 where (a1, a2) in (select '1 - 01', '2 - 01' from dual);
/****************************************************************************** * Subqueries in other uncovered clauses. ******************************************************************************/ /* SELECT clause */ select ((a1,a2) IN (select * from t2 where b2 > '0')) IS NULL from t1;
/* GROUP BY clause */ create table columns (col int key);
insert into columns values (1), (2);
set @previous_sql_mode_htnt542nh=@@sql_mode;
set sql_mode=(select replace(@@sql_mode,'ONLY_FULL_GROUP_BY',''));
explain select * from t1 group by (select col from columns limit 1);
select * from t1 group by (select col from columns limit 1);
explain select * from t1 group by (a1 in (select col from columns));
select * from t1 group by (a1 in (select col from columns));
set @@sql_mode=@previous_sql_mode_htnt542nh;
/* ORDER BY clause */ explain select * from t1 order by (select col from columns limit 1);
select * from t1 order by (select col from columns limit 1);
/****************************************************************************** * Column types/sizes that affect materialization. ******************************************************************************/ # test for BIT fields create table t1bit (a1 bit(3), a2 bit(3));
create table t2bit (b1 bit(3), b2 bit(3));
insert into t1bit values (b'000', b'100');
insert into t1bit values (b'001', b'101');
insert into t1bit values (b'010', b'110');
insert into t2bit values (b'001', b'101');
