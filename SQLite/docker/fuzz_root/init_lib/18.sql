CREATE TABLE t1(a INT, b INT);
CREATE TABLE t2(c INT, d INT);
CREATE TABLE t3(e TEXT, f TEXT);
INSERT INTO t1 VALUES(1, 1);
INSERT INTO t2 VALUES(1, 2);
SELECT * FROM t1 JOIN t2 ON (t2.c=t1.a) LEFT JOIN t3 ON (t2.d=1);
