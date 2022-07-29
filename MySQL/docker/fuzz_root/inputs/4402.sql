CREATE TABLE t1 ( pk int NOT NULL, col_int_key int DEFAULT NULL, col_int int DEFAULT NULL, col_varchar varchar(1) DEFAULT NULL, PRIMARY KEY (pk), KEY col_int_key (col_int_key) );
INSERT INTO t1 VALUES (10,7,5,'l'), (12,7,4,'o');
ANALYZE TABLE t1, t2, t3;
SET SQL_MODE='';
SET sql_mode='';
PREPARE prep_stmt FROM "SELECT t2.f1 FROM (t2 LEFT JOIN t1  ON (1 = ANY (SELECT f1 FROM t1 WHERE 1 IS NULL)))" ;
EXECUTE prep_stmt ;
