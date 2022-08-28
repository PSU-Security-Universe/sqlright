CREATE TABLE t1( a INT,  b INTEGER,  c TEXT,  d REAL,  e BLOB) STRICT;
CREATE TABLE t1nn(  a INT NOT NULL,  b INTEGER NOT NULL,  c TEXT NOT NULL,  d REAL NOT NULL,  e BLOB NOT NULL) STRICT;
CREATE TABLE t2(a,b,c,d,e);
INSERT INTO t1(a,b,c,d,e) VALUES(1,1,'one',1.0,x'b1'),(2,2,'two',2.25,x'b2b2b2');
PRAGMA writable_schema=on;
PRAGMA quick_check('t1');
UPDATE sqlite_schema SET rootpage=(SELECT rootpage FROM sqlite_schema WHERE name='t1');
