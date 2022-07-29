SET optimizer_switch='subquery_to_derived=on';
CREATE TABLE t1(a INT);
INSERT INTO t1 VALUES (1),(2),(3),(4);
ANALYZE TABLE t1, t2, t0, t3;
