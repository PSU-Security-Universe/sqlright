PRAGMA encoding = 'utf-16';
CREATE TABLE t1(abcd, efgh);
INSERT INTO t1 VALUES (0, 0);
CREATE VIEW v1 AS SELECT * FROM t1 WHERE abcd>efgh;
