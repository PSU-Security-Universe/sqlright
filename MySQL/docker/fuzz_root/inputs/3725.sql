CREATE TABLE t1 (f1 INT, f2 INT, f3 CHAR(1), f4 CHAR(1), f5 CHAR(1), f6 CHAR(1), f7 CHAR(1), PRIMARY KEY (f5, f1), KEY (f2), KEY (f3), KEY (f4), KEY(f7) );
INSERT INTO t1 VALUES (1, 1, 'a', 'h', 'i', '', ''), (2, 3, 'a', 'h', 'i', '', ''), (3, 2, 'b', '', 'j', '', ''), (4, 2, 'b', '', 'j', '', '');
ANALYZE TABLE t1;
SET optimizer_switch='index_merge_intersection=off';
ALTER TABLE t1 ADD KEY idx(f3, f4);
