CREATE TABLE t1(a);
CREATE INDEX i1 ON t1(a);
INSERT INTO t1 VALUES(1);
INSERT INTO t1 VALUES(2);
INSERT INTO t1 VALUES(3);
DROP INDEX i1;
SELECT 2 IN (SELECT a FROM t1);