RESET MASTER;
SET GTID_NEXT= 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa:1';
CREATE TABLE t1 (c1 INT);
SET GTID_NEXT= 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa:2';
BEGIN;
BEGIN;
INSERT INTO t1 VALUES (1);
BEGIN;
COMMIT;
SET GTID_NEXT= 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa:3';
DROP TABLE t1;