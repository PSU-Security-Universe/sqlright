CREATE TABLE t3651(a UNIQUE);
INSERT INTO t3651 VALUES(5);
ALTER TABLE t3651 ADD COLUMN b UNIQUE;
ALTER TABLE t3651 ADD COLUMN b PRIMARY KEY;
ALTER TABLE t3651 RENAME TO xyz;
ALTER TABLE xyz ADD COLUMN xyz;
