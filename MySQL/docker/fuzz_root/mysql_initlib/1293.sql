CREATE TABLE t1(a INT);
ALTER INSTANCE RELOAD TLS;
DROP TABLE t1;
RESET MASTER;