SHOW VARIABLES LIKE 'character_sets_dir%';
SHOW COLLATION LIKE 'utf8_phone_ci';
CREATE TABLE t1 (pk INTEGER) COLLATE utf8_phone_ci;
SHOW CREATE TABLE t1;
DROP TABLE t1;
SHOW VARIABLES LIKE 'character_sets_dir%';
SHOW COLLATION LIKE 'utf8_phone_ci';
CREATE TABLE t1 (pk INTEGER) COLLATE utf8_phone_ci;
