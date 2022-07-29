CREATE TABLE t0 (c0);
CREATE TABLE t1 (c0);
CREATE TABLE t2 (c0);
INSERT INTO t1(c0) VALUES ('x');
INSERT INTO t2 VALUES ('1'), ('2');
SELECT count(*) FROM t0 RIGHT OUTER JOIN t1 LEFT OUTER JOIN t2 ON t0.c0;
SELECT count(*) FROM t0 RIGHT OUTER JOIN t1 LEFT OUTER JOIN t2 ON t0.c0 WHERE t2.c0;
