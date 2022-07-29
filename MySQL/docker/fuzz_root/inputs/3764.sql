CREATE TABLE t1 ( pk INT PRIMARY KEY AUTO_INCREMENT, i INT, j INT, INDEX (i), INDEX (j) );
INSERT INTO t1 (i,j) VALUES (1,1);
set @d=1;
ANALYZE TABLE t1;
SET @@SESSION.sql_mode='NO_ENGINE_SUBSTITUTION';
SET optimizer_trace = "enabled=on", optimizer_trace_max_mem_size = 1000000, end_markers_in_json = ON;
