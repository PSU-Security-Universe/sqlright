CREATE TABLE t1( w INT GENERATED ALWAYS AS (a*10), x TEXT AS (typeof(c)), y TEXT AS (substr(b,a,a+2)), a INT, b TEXT, c ANY);
CREATE TABLE t0(c0 PRIMARY KEY, c1, c2 AS (c0+c1-c3) REFERENCES t0, c3);
INSERT INTO t0 VALUES (0, 0, 0), (11, 5, 5);
UPDATE t0 SET c1 = c0, c3 = c0;
INSERT INTO t1(a,b,c) VALUES(1,'abcdef',5.5),(3,'cantaloupe',NULL);
SELECT w, x, y, '|' FROM t1 ORDER BY a;
SELECT *, '|' FROM t0 ORDER BY +c0;
