CREATE TABLE t1(a,b);
INSERT INTO t1 VALUES(1,11);
INSERT INTO t1 VALUES(2,22);
INSERT INTO t1 SELECT a+2, b+22 FROM t1;
INSERT INTO t1 SELECT a+4, b+44 FROM t1;
CREATE TABLE t2(c,d);
INSERT INTO t2 SELECT a, 900+b FROM t1;
PRAGMA automatic_index=ON;
SELECT b, d FROM t1 JOIN t2 ON a=c ORDER BY b;
