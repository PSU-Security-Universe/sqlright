CREATE TABLE t1(a,b,c);
CREATE INDEX t1a ON t1(a) WHERE a IS NOT NULL;
CREATE INDEX t1b ON t1(b) WHERE b>10;
CREATE INDEX bad1 ON t1(a,b) WHERE a!=1;
CREATE VIRTUAL TABLE nums USING wholenumber;
INSERT INTO t1(a,b,c) SELECT CASE WHEN value%3!=0 THEN value END, value, value FROM nums WHERE value<=20;
SELECT count(a), count(b) FROM t1;
PRAGMA integrity_check;
SELECT count(*) FROM t1;
