CREATE TABLE t1 (i int, b JSON DEFAULT (JSON_OBJECT("key", i)));
INSERT INTO t1(i) VALUES (1);
INSERT INTO t1 SET i = 10;
INSERT INTO t1(i, b) VALUES (2, DEFAULT);
INSERT INTO t1 SET i = 20, b = DEFAULT;
INSERT INTO t1(i, b) VALUES (3, JSON_OBJECT("key", 3));
INSERT INTO t1 SET i = 30, b = JSON_OBJECT("key", 30);
SELECT * FROM t1;
ALTER TABLE t1 DROP COLUMN b;
DROP TABLE t1;
CREATE TABLE t1 (i int, b char(255) DEFAULT (md5(i)), INDEX (b(10)));
INSERT INTO t1(i) VALUES (1);
INSERT INTO t1(i, b) VALUES (2, DEFAULT);
INSERT INTO t1(i, b) VALUES (3, "some string");
SELECT * FROM t1;
DROP TABLE t1;
CREATE TABLE t1 (i int);
INSERT INTO t1(i) VALUES (1),(2);
ALTER TABLE t1 ADD COLUMN b JSON DEFAULT (JSON_OBJECT("key",i));
INSERT INTO t1(i) VALUES (3);
INSERT INTO t1(i, b) VALUES (4, DEFAULT);
INSERT INTO t1(i, b) VALUES (5, JSON_OBJECT("key", 5));
SELECT * FROM t1;
DROP TABLE t1;
CREATE TABLE t1 (i int);
INSERT INTO t1(i) VALUES (1),(2);
ALTER TABLE t1 ADD COLUMN b JSON;
ALTER TABLE t1 ALTER COLUMN b SET DEFAULT (JSON_OBJECT("key",i));
INSERT INTO t1(i) VALUES (3);
INSERT INTO t1(i, b) VALUES (4, DEFAULT);
INSERT INTO t1(i, b) VALUES (5, JSON_OBJECT("key", 5));
SELECT * FROM t1;
DROP TABLE t1;
CREATE TABLE t1 (i int);
INSERT INTO t1(i) VALUES (1),(2);
ALTER TABLE t1 ADD COLUMN b JSON DEFAULT (JSON_ARRAY());
INSERT INTO t1(i) VALUES (4);
ALTER TABLE t1 CHANGE COLUMN b new_b JSON DEFAULT (JSON_OBJECT("key",i));
INSERT INTO t1(i) VALUES (5);
INSERT INTO t1(i, new_b) VALUES (6, DEFAULT);
INSERT INTO t1(i, new_b) VALUES (7, JSON_OBJECT("key", 7));
SELECT * FROM t1;
DROP TABLE t1;
CREATE TABLE t1 (i int, b int DEFAULT (123 * 1));
ALTER TABLE t1 CHANGE COLUMN i new_i JSON DEFAULT (JSON_ARRAY(b));
DROP TABLE t1;
CREATE TABLE t1 (i int);
INSERT INTO t1(i) VALUES (1),(2);
ALTER TABLE t1 ADD COLUMN b JSON DEFAULT (JSON_ARRAY());
INSERT INTO t1(i) VALUES (4);
ALTER TABLE t1 MODIFY COLUMN b JSON DEFAULT (JSON_OBJECT("key",i)) FIRST;
INSERT INTO t1(i) VALUES (5);
INSERT INTO t1(i, b) VALUES (6, DEFAULT);
INSERT INTO t1(i, b) VALUES (7, JSON_OBJECT("key", 7));
SELECT * FROM t1;
DROP TABLE t1;
CREATE TABLE t1 (i int, b int DEFAULT (123 * 1));
ALTER TABLE t1 MODIFY COLUMN i JSON DEFAULT (JSON_ARRAY(b)) FIRST;
DROP TABLE t1;
CREATE TABLE t1 (i JSON DEFAULT (JSON_ARRAY(b)), b int DEFAULT 123);
DROP TABLE t1;
CREATE TABLE t1 (b int DEFAULT 123, i JSON DEFAULT (JSON_ARRAY(b)));
DROP TABLE t1;
CREATE TABLE t1 (i JSON DEFAULT (JSON_ARRAY(b)), b int DEFAULT (123 * 1));
CREATE TABLE t1 (b int DEFAULT (123 * 1), i JSON DEFAULT (JSON_ARRAY(b)));
DROP TABLE t1;
CREATE TABLE t1 (i int, b JSON);
INSERT INTO t1(i) VALUES (1),(2);
ALTER TABLE t1 ALTER COLUMN b SET DEFAULT (JSON_OBJECT("key",i));
INSERT INTO t1(i) VALUES (3);
INSERT INTO t1(i, b) VALUES (4, DEFAULT);
INSERT INTO t1(i, b) VALUES (5, JSON_OBJECT("key", 5));
ALTER TABLE t1 ALTER COLUMN b DROP DEFAULT;
INSERT INTO t1(i, b) VALUES (6, NULL);
SELECT * FROM t1;
DROP TABLE t1;
CREATE TABLE t1 (id int(11) PRIMARY KEY auto_increment, f1 JSON DEFAULT (JSON_OBJECT("key", id)));
CREATE TABLE t1 (a varchar(64), b varchar(1024) DEFAULT (load_file(a)));
CREATE TABLE t1 (f1 JSON DEFAULT (JSON_OBJECT("key", id)), id int(11));
INSERT INTO t1(id) VALUES(1), (2), (3);
SELECT * FROM t1;
DROP TABLE t1;
CREATE TABLE t1 (id char(2) DEFAULT (uuid()));
INSERT INTO t1 VALUES (),(),();
DROP TABLE t1;
CREATE TABLE t3 (a INT PRIMARY KEY, b INT GENERATED ALWAYS AS (-a) VIRTUAL UNIQUE DEFAULT (-1 * 128));
CREATE TABLE t3 (a INT PRIMARY KEY, c INT GENERATED ALWAYS AS (-a) STORED DEFAULT (-1 * 128));
CREATE TABLE t1 (id char(36) DEFAULT (uuid()));
INSERT INTO t1 VALUES (),(),();
CREATE TABLE t2 as SELECT * from t1;
SHOW CREATE TABLE t2;
CREATE TABLE t3 LIKE t1;
SHOW CREATE TABLE t3;
SELECT LENGTH(id) FROM t1;
SHOW CREATE TABLE t1;
SHOW COLUMNS FROM t1;
DESCRIBE t1;
DROP TABLE t1;
DROP TABLE t2;
DROP TABLE t3;
CREATE TABLE t3 (a INT PRIMARY KEY, d INT DEFAULT (-a + 1), c INT DEFAULT (DEFAULT(d)) );
CREATE TABLE t3 (a INT PRIMARY KEY, d INT DEFAULT (-a + 1), c INT DEFAULT (-d) );
SELECT DEFAULT(d) from t3;
SELECT DEFAULT(c) from t3;
ALTER TABLE t3 DROP COLUMN d;
DROP TABLE t3;
CREATE TABLE `t1` (i varchar(200) DEFAULT (_utf8mb4"\U+1F9DB♀"));
SELECT COLUMN_NAME, COLUMN_DEFAULT, DATA_TYPE, EXTRA, GENERATION_EXPRESSION FROM information_schema.columns WHERE table_name= "t1";
INSERT INTO t1 values (),();
SELECT * from t1;
DESCRIBE t1;
DROP TABLE t1;
CREATE TABLE test ( id INT UNSIGNED NOT NULL AUTO_INCREMENT, data VARCHAR(64) DEFAULT NULL, something VARCHAR(64) NOT NULL DEFAULT (CONCAT ('[', data, ']')), PRIMARY KEY (id) );
REPLACE INTO test VALUES (1, 'Old', DEFAULT);
SELECT * FROM test;
REPLACE INTO test VALUES (1, 'New', DEFAULT);
SELECT * FROM test;
DROP TABLE test;
CREATE TABLE t(i INT, b TINYBLOB  DEFAULT (repeat('b', i)));
SHOW CREATE TABLE t;
INSERT INTO t values(254, DEFAULT);
INSERT INTO t values(255, DEFAULT);
