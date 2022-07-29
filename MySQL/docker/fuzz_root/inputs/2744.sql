set optimizer_switch='batched_key_access=on,block_nested_loop=off,mrr_cost_based=off';
CREATE TABLE t1 ( grp int(11) default NULL, a bigint(20) unsigned default NULL, c char(10) NOT NULL default '' ) ENGINE=MyISAM;
INSERT INTO t1 VALUES (1,1,'a'),(2,2,'b'),(2,3,'c'),(3,4,'E'),(3,5,'C'),(3,6,'D'),(NULL,NULL,'');
create table t2 (id int, a bigint unsigned not null, c char(10), d int, primary key (a));
insert into t2 values (1,1,"a",1),(3,4,"A",4),(3,5,"B",5),(3,6,"C",6),(4,7,"D",7);
set @previous_sql_mode_htnt542nh=@@sql_mode;
set sql_mode=(select replace(@@sql_mode,'ONLY_FULL_GROUP_BY',''));
