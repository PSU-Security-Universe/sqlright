SET @old_innodb_stats_persistent= @@global.innodb_stats_persistent;
create table thread_to_monitor(thread_id int);
insert into thread_to_monitor(thread_id) SELECT THREAD_ID FROM performance_schema.threads WHERE PROCESSLIST_ID=CONNECTION_ID();
CREATE TABLE t1 (a int PRIMARY KEY, b varchar(128), KEY (b)) ENGINE = InnoDB PARTITION BY HASH (a) PARTITIONS 13;
SHOW CREATE TABLE t1;
FLUSH STATUS;
INSERT INTO t1 VALUES (1, 'First row, p1');
UPDATE t2 SET b = CONCAT(b, ", UPDATED") WHERE a = 10;
