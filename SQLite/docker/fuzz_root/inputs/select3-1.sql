CREATE TABLE t1(n int, log int);
BEGIN;
INSERT INTO t1 VALUES(2, 1);
INSERT INTO t1 VALUES(3, 1);
INSERT INTO t1 VALUES(4, 1);
INSERT INTO t1 VALUES(4, 3);
SELECT min(n),min(log),max(n),max(log),sum(n),sum(log),avg(n),avg(log) FROM t1;
SELECT log, avg(n)+1 FROM t1 GROUP BY log ORDER BY log;
SELECT log*2+1 AS x, count(*) AS y FROM t1 GROUP BY x ORDER BY 10-(x+y);
SELECT log, count(*) FROM t1 GROUP BY log HAVING count(*)>=4 ORDER BY log;
SELECT log, count(*), avg(n), max(n+log*2) FROM t1 GROUP BY log ORDER BY max(n+log*2)+0, min(log,avg(n))+0;

