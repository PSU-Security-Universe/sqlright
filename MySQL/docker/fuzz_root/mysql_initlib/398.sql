CREATE TABLE `bug21328` ( `col1` int(11) NOT NULL, `col2` int(11) NOT NULL, `col3` int(11) NOT NULL ) ENGINE=CSV;
insert into bug21328 values (1,0,0);
alter table bug21328 engine=myisam;
drop table bug21328;
