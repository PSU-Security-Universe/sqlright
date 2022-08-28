CREATE TABLE t1(a INTEGER, b TEXT, c BLOB, CHECK( coalesce(b,c) ));
INSERT INTO t1 VALUES(1, 2, 3);
ALTER TABLE t1 RENAME COLUMN b TO d;
CREATE TABLE t3(a, b, c, d, e, f, g, h, i, j, k, l, m, FOREIGN KEY (b, c, d, e, f, g, h, i, j, k, l, m) REFERENCES t4);
CREATE TABLE t4(x, y, z);
INSERT INTO t4 VALUES(3, 2, 1);
