purge master logs before (select adddate(current_timestamp(), interval -4 day));
create table t1(a int,b int,key(a),key(b));
insert into t1(a,b) values (1,2),(2,1),(2,3),(3,4),(5,4),(5,5), (6,7),(7,4),(5,3);
CREATE TABLE t1 (f1 INT NOT NULL);
