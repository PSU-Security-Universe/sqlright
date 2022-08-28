BEGIN;
create TABLE abc(a, b, c, PRIMARY KEY(a, b));
INSERT INTO abc VALUES(1, 1, 1);
INSERT INTO abc SELECT a+(select max(a) FROM abc), b+(select max(a) FROM abc), c+(select max(a) FROM abc) FROM abc;
COMMIT;
SELECT count((SELECT a FROM abc WHERE a = NULL AND b >= upper.c)) FROM abc AS upper;
SELECT * FROM sqlite_master WHERE rowid=10;
