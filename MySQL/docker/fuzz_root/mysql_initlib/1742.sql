set @old_concurrent_insert= @@global.concurrent_insert;
set @@global.concurrent_insert= 0;
drop table if exists t1;
create table t1 ( `a&b` int, `a<b` int, `a>b` text );
insert into t1 values (1, 2, 'a&b a<b a>b');
drop table t1;
set @@global.concurrent_insert= @old_concurrent_insert;
