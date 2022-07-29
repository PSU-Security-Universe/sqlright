SET @@SESSION.pseudo_replica_mode=1;
BINLOG '0';
CREATE TABLE t1(i TEXT, FULLTEXT INDEX tix (i)) ENGINE=InnoDB;
XA START 'xa1','';
INSERT INTO t1 VALUES ('abc');
XA END 'xa1','';
XA PREPARE 'xa1','';
DROP TABLE t1;;
XA COMMIT 'xa1';
