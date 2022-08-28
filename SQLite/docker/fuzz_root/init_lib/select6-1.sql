DROP TABLE IF EXISTS t1;
CREATE TABLE t1(w INT, x INT);
INSERT INTO t1(w,x) VALUES(1,10),(2,20),(3,30), (2,21),(3,31), (3,32);
CREATE INDEX t1wx ON t1(w,x);

DROP TABLE IF EXISTS t2;
CREATE TABLE t2(w INT, y VARCHAR(8));
INSERT INTO t2(w,y) VALUES(1,'one'),(2,'two'),(3,'three'),(4,'four');
CREATE INDEX t2wy ON t2(w,y);

SELECT cnt, xyz, (SELECT y FROM t2 WHERE w=cnt), '|' FROM (SELECT count(*) AS cnt, w AS xyz FROM t1 GROUP BY 2) ORDER BY cnt, xyz;
SELECT cnt, xyz, lower((SELECT y FROM t2 WHERE w=cnt)), '|' FROM (SELECT count(*) AS cnt, w AS xyz FROM t1 GROUP BY 2) ORDER BY cnt, xyz;
SELECT cnt, xyz, CASE WHEN (SELECT y FROM t2 WHERE w=cnt)=='two' THEN 'aaa' ELSE 'bbb' END, '|' FROM (SELECT count(*) AS cnt, w AS xyz FROM t1 GROUP BY 2) ORDER BY +cnt;
