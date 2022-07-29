CREATE TABLE t1(a BLOB, b VARCHAR(255) CHARSET LATIN1, c INT, KEY(b, c, a(765))) ENGINE=INNODB;
INSERT INTO t1(a, b, c) VALUES ('', 'a', 0), ('', 'a', null), ('', 'a', 0), ('', 'a', null), ('', 'a', 0);
ANALYZE TABLE t1;
SELECT MIN(c) FROM t1 GROUP BY b;
EXPLAIN SELECT MIN(c) FROM t1 GROUP BY b;
DROP TABLE t1;
