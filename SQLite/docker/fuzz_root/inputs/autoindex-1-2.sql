CREATE TABLE t1(x INTEGER PRIMARY KEY, y, z);
CREATE TABLE t2(a, b);
CREATE VIEW agg2 AS SELECT a, sum(b) AS m FROM t2 GROUP BY a;
SELECT t1.z, agg2.m FROM t1 JOIN agg2 ON t1.y=agg2.m WHERE t1.x IN (1,2,3);
CREATE TABLE t920(x);
INSERT INTO t920 VALUES(3),(4),(5); 
SELECT * FROM t920,(SELECT 0 FROM t920),(VALUES(9)) WHERE 5 IN (x);
