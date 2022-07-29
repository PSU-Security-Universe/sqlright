set sql_mode="";
create table t1(a int)engine=innodb;
create table t2(b int)engine=innodb;
call p1();   # run this in two connections!;
call p1();
drop procedure p1;
drop table t1,t2;
set sql_mode=default;
