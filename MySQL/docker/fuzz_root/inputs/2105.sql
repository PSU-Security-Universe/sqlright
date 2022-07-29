CREATE TABLE t0 ( i0 INTEGER );
INSERT INTO t0 VALUES (0),(1),(2),(3),(4);
SET optimizer_switch="derived_merge=off,derived_condition_pushdown=on";
set sql_mode="";
SET @p1 = 3;
PREPARE p FROM "SELECT f1 FROM (SELECT f1 FROM t1) as dt WHERE f1 > ?";
EXECUTE p USING @p1;
CALL p();
