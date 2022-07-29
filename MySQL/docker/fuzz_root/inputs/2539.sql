create table t1 (a int);
insert into t1 values (null);
analyze table t1;
CREATE TABLE t1 ( raw_id int(10) NOT NULL default '0', chr_start int(10) NOT NULL default '0', chr_end int(10) NOT NULL default '0', raw_start int(10) NOT NULL default '0', raw_end int(10) NOT NULL default '0', raw_ori int(2) NOT NULL default '0' );
INSERT INTO t1 VALUES (469713,1,164123,1,164123,1),(317330,164124,317193,101,153170,1),(469434,317194,375620,101,58527,1),(591816,375621,484273,1,108653,1),(591807,484274,534671,91,50488,1),(318885,534672,649362,101,114791,1),(318728,649363,775520,102,126259,1),(336829,775521,813997,101,38577,1),(317740,813998,953227,101,139330,1),(1,813998,953227,101,139330,1);
set @previous_sql_mode_htnt542nh=@@sql_mode;
set sql_mode=(select replace(@@sql_mode,'ONLY_FULL_GROUP_BY',''));
set names latin1;
