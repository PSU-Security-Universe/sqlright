CREATE TABLE t1(a,b INT);
INSERT INTO t1(a,b) VALUES(1,2),(3,3),(4,5);
CREATE UNIQUE INDEX i1 ON t1(b,b,a,a,a,a,a,b,a);
ANALYZE;
DROP TABLE IF EXISTS sqlite_stat4;
INSERT INTO sqlite_stat1 VALUES('t1','i1','30 30 30 2 2 2 2 2 2 2');
ANALYZE sqlite_master;
