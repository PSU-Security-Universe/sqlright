CREATE TABLE t1(a INT, b INT);
INSERT INTO t1(a,b) VALUES(1,null),(null,null),(1,null);
CREATE UNIQUE INDEX t1b ON t1(abs(b));
SELECT quote(a), quote(b), '|' FROM t1 GROUP BY a, abs(b);
