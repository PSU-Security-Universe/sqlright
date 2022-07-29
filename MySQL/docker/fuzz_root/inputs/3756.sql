set optimizer_switch='semijoin=on,materialization=on,firstmatch=on,loosescan=on,index_condition_pushdown=on,mrr=on,mrr_cost_based=off';
SET sql_mode = 'NO_ENGINE_SUBSTITUTION';
CREATE TABLE t1 ( id int(6) DEFAULT '0' NOT NULL, idservice int(5), clee char(20) NOT NULL, flag char(1), KEY id (id), PRIMARY KEY (clee) );
INSERT INTO t1 VALUES (2,4,'6067169d','Y');
create table t1 (first char(10),last char(10));
insert into t1 values ("Michael","Widenius");
ANALYZE TABLE t1;
alter table t1 modify b int not null, modify c varchar(10) not null;
