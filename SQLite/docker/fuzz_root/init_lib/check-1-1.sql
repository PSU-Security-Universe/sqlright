PRAGMA writable_schema = 1;
CREATE TABLE t2(x INTEGER CONSTRAINT one CHECK( typeof(coalesce(x,0))=="integer" ), y REAL CONSTRAINT two CHECK( typeof(coalesce(y,0.1))=='real' ), z TEXT CONSTRAINT three CHECK( typeof(coalesce(z,''))=='text' ));
CREATE TABLE t2n( x INTEGER CONSTRAINT one CHECK( typeof(coalesce(x,0))=="integer" ), y NUMERIC CONSTRAINT two CHECK( typeof(coalesce(y,0.1))=='real' ), z TEXT CONSTRAINT three CHECK( typeof(coalesce(z,''))=='text' ));
INSERT INTO t2 VALUES(1,2.2,'three');
SELECT * FROM t2;
