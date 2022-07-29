drop table if exists t1;
SET SQL_WARNINGS=1;
create table t1 (this int unsigned);
insert into t1 values (1);
insert ignore into t1 values (-1);
insert ignore into t1 values ('5000000000');
select * from t1;
drop table t1;
