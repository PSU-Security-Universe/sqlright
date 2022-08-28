CREATE TABLE t1( a INTEGER PRIMARY KEY, b INTEGER REFERENCES t1 ON DELETE CASCADE REFERENCES t2, c TEXT, FOREIGN KEY (b,c) REFERENCES t2(x,y) ON UPDATE CASCADE);
CREATE TABLE t2( x INTEGER PRIMARY KEY, y TEXT);
CREATE TABLE t3( a INTEGER REFERENCES t2, b INTEGER REFERENCES t1, FOREIGN KEY (a,b) REFERENCES t2(x,y) );
INSERT INTO t1 (1, 2, 'c');
INSERT INTO t1 (1, 2, 'c');
INSERT INTO t2 (1, 'b');
INSERT INTO t2 (1, 'b');
INSERT INTO t2 (1, 2);
INSERT INTO t2 (1, 2);
