CREATE TABLE t1(f1 INT, f2 INT);
INSERT INTO t1 VALUES (1,1),(2,2),(3,3);
ANALYZE TABLE t1;
set optimizer_switch=default;
FLUSH STATUS;
SHOW STATUS LIKE 'handler_read%';
PREPARE stmt1 FROM "SELECT /*+ BKA(t2) */ t2.f1, t2.f2, t2.f3 FROM t1,t2 WHERE t1.f1=t2.f1 AND t2.f2 BETWEEN t1.f1 and t1.f2 and t2.f2 + 1 >= t1.f1 + 1";
EXECUTE stmt1;
DEALLOCATE PREPARE stmt1;
