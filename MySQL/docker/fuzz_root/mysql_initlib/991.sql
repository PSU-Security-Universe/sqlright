drop table if exists t1,t2,t3,t4,t5,t6,t7;
SET sql_mode = 'NO_ENGINE_SUBSTITUTION';
create table t1 (a text, unique (a(2100))) engine=myisam;
create table t1 (a text, key (a(2100))) engine=myisam;
show create table t1;
drop table t1;
