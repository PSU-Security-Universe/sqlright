CREATE TABLE x1(one, two, three, PRIMARY KEY(one), CHECK (three!="xyz"), CHECK (two!="one")) WITHOUT ROWID;
CREATE INDEX x1i ON x1(one+"two"+"four") WHERE "five";
CREATE TEMP TRIGGER tri1 AFTER INSERT ON x1 BEGIN UPDATE x1 SET two=new.three || "new" WHERE one=new.one||"new"; END;
CREATE TABLE t1(a, b, c, d, PRIMARY KEY(d, b)) WITHOUT ROWID;
INSERT INTO t1 VALUES(1, 2, 3, 4);
ALTER TABLE t1 DROP COLUMN c;
