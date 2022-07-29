SET @@session.myisam_sort_buffer_size = 4294967296;
SET @@session.myisam_sort_buffer_size = 8388608;
SET SESSION sort_buffer_size = 18446744073709551615;
CREATE TABLE t0(c0 INT UNIQUE, c1 INT UNIQUE);
INSERT INTO t0(c0) VALUES(1), (2), (3);
SELECT * FROM t0 WHERE NOT((t0.c1 IS NULL) AND ((t0.c0) != (1)));
DROP TABLE t0;
SET SESSION sort_buffer_size = default;
