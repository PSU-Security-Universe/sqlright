CREATE TABLE t1(a);
INSERT INTO t1 VALUES('abc'),('def'),('ghi');
CREATE TABLE t2(a);
INSERT INTO t2 VALUES('DEF'),('abc');
CREATE TABLE t3(a);
INSERT INTO t3 VALUES('def'),('jkl');
SELECT a FROM t1 EXCEPT SELECT a FROM t2 ORDER BY a COLLATE nocase;
SELECT a FROM t2 EXCEPT SELECT a FROM t3 ORDER BY a COLLATE nocase;
SELECT a FROM t2 EXCEPT SELECT a FROM t3 ORDER BY a COLLATE binary;
DELETE FROM t2;
DELETE FROM t3;
INSERT INTO t2 VALUES('ABC'),('def'),('GHI'),('jkl');
INSERT INTO t3 SELECT lower(a) FROM t2; 
SELECT a COLLATE nocase FROM t2 EXCEPT SELECT a FROM t3 ORDER BY 1
