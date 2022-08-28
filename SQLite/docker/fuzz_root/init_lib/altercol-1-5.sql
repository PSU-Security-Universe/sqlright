CREATE TABLE t4(id INTEGER PRIMARY KEY, c1 INT, c2 INT);
CREATE VIEW t4v1 AS SELECT id, c1, c99 FROM t4;
DELETE FROM schema_copy;
INSERT INTO schema_copy SELECT name, sql FROM sqlite_schema;
BEGIN;
PRAGMA writable_schema=ON;
ALTER TABLE t4 RENAME to t4new;
SELECT name FROM sqlite_schema WHERE (name,sql) NOT IN (SELECT * FROM schema_copy);
ROLLBACK;
