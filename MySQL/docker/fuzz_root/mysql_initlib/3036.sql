CREATE TABLE t1 (a INT) SECONDARY_ENGINE=gizmo;
SHOW CREATE TABLE t1;
SET SESSION show_create_table_skip_secondary_engine=on;
SHOW CREATE TABLE t1;
SET SESSION show_create_table_skip_secondary_engine=default;
DROP TABLE t1;
