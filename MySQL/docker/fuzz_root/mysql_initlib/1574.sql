select 1+1;
select 1+2;
SHOW GLOBAL VARIABLES LIKE 'thread_handling';
select @@session.thread_handling;
set GLOBAL thread_handling='one-thread';
