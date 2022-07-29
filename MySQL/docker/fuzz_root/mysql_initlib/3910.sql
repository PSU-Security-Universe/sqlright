DROP TABLE IF EXISTS t1, t2;
CREATE TABLE t1 (a INT) PARTITION BY RANGE (a) (PARTITION p0 VALUES LESS THAN (6), PARTITION `p1....................` VALUES LESS THAN (9), PARTITION p2 VALUES LESS THAN MAXVALUE);
INSERT INTO t1 VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10);
RENAME TABLE t1 TO `t2_............................end`;
SELECT * FROM `t2_............................end`;
RENAME TABLE `t2_............................end` to t1;
SELECT * FROM t1;
DROP TABLE t1;
