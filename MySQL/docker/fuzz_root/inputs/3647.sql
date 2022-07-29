SET NAMES utf8;
CREATE TABLE t1 (d DOUBLE, id INT, sex CHAR(1));
INSERT INTO t1 VALUES (1.0, 1, 'M'), (2.0, 2, 'F'), (3.0, 3, 'F'), (4.0, 4, 'F'), (5.0, 5, 'M'), (NULL, NULL, 'M'), (10.0, 10, NULL), (10.0, 10, NULL), (11.0, 11, NULL);
PREPARE p FROM "SELECT id, sex, NTH_VALUE(id, ?) OVER () FROM t1";
SET @p1= 3;
EXECUTE p USING @p1;
SET SESSION SQL_MODE='';
