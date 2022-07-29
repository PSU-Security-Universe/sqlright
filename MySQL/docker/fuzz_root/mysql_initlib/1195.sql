use mysql;
create database MYSQLtest;
select * from db where user = 'mysqltest_1';
update db set db = 'MYSQLtest' where db = 'mysqltest' and user = 'mysqltest_1' and host = 'localhost';
flush privileges;
select * from db where user = 'mysqltest_1';
delete from db where db = 'MYSQLtest' and user = 'mysqltest_1' and host = 'localhost';
flush privileges;
drop database MYSQLtest;
