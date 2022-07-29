create table t1 ( a1 char(64), a2 char(64), b char(16), c char(16) not null, d char(16), dummy char(248) default ' ' ) charset latin1;
analyze table t1;
insert into t2 select * from t1;
set @previous_sql_mode_htnt542nh=@@sql_mode;
set sql_mode=(select replace(@@sql_mode,'ONLY_FULL_GROUP_BY',''));
