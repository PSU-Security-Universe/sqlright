CREATE TABLE t1 (c1 INT, KEY(c1));
INSERT INTO t1 VALUES (19910113), (20010514), (19930513), (19970416), (19960416), (19950414);
ANALYZE TABLE t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13;
set optimizer_switch='semijoin=off,materialization=on,subquery_materialization_cost_based=off';
SET TIMESTAMP=UNIX_TIMESTAMP(20150413000000);
