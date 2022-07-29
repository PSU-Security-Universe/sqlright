SET autocommit=1;
SELECT @@session.session_track_system_variables INTO @old_track_list;
SET @track_list= CONCAT(@old_track_list, ",transaction_isolation,                                            transaction_read_only");
SET SESSION session_track_system_variables=@track_list;
SELECT @@session.session_track_state_change INTO @old_track_enable;
SET SESSION session_track_state_change=TRUE;
SELECT @@session.session_track_transaction_info INTO @old_track_tx;
FLUSH STATUS;
SET SESSION session_track_transaction_info="STATE";
START TRANSACTION;
COMMIT;
CREATE TABLE t1 (f1 INT) ENGINE="InnoDB";
START TRANSACTION;
DROP TABLE t1;
START TRANSACTION;
SET @dummy=0;
ROLLBACK;
SET autocommit=0;
CREATE TABLE t1 (f1 INT) ENGINE="InnoDB";
INSERT INTO t1 VALUES (1);
SELECT f1 FROM t1 LIMIT 1 INTO @dummy;
SELECT f1 FROM t1;
BEGIN WORK;
DROP TABLE t1;
SELECT RAND(22) INTO @dummy;
COMMIT;
CREATE TABLE t1 (f1 INT) ENGINE="InnoDB";
SET TRANSACTION READ ONLY;
SET TRANSACTION READ WRITE;
SELECT RAND(22) INTO @dummy;
SET TRANSACTION READ WRITE;
INSERT INTO t1 VALUES (1);
SET TRANSACTION READ WRITE;
DROP TABLE t1;
SET autocommit=1;
CREATE TABLE t1 (f1 INT) ENGINE="InnoDB";
CREATE TABLE t2 (f1 INT) ENGINE="InnoDB";
INSERT INTO  t1 VALUES (123);
BEGIN;
SELECT f1 FROM t1;
COMMIT AND CHAIN;
INSERT INTO t2 SELECT f1 FROM t1;
COMMIT;
DROP TABLE t1;
DROP TABLE t2;
SET SESSION session_track_transaction_info="CHARACTERISTICS";
START TRANSACTION;
START TRANSACTION WITH CONSISTENT SNAPSHOT;
START TRANSACTION READ WRITE;
START TRANSACTION READ ONLY;
START TRANSACTION READ WRITE, WITH CONSISTENT SNAPSHOT;
START TRANSACTION READ ONLY,  WITH CONSISTENT SNAPSHOT;
COMMIT AND CHAIN;
SET TRANSACTION   READ ONLY;
ROLLBACK;
SET TRANSACTION   READ ONLY;
SET TRANSACTION              ISOLATION LEVEL REPEATABLE READ;
SET TRANSACTION   READ ONLY;
SET TRANSACTION   READ WRITE;
SET TRANSACTION              ISOLATION LEVEL REPEATABLE READ;
SET TRANSACTION   READ ONLY, ISOLATION LEVEL SERIALIZABLE;
BEGIN WORK;
COMMIT;
SET SESSION transaction_read_only=0;
SET TRANSACTION READ ONLY;
START TRANSACTION;
COMMIT;
SET TRANSACTION READ WRITE;
START TRANSACTION;
COMMIT;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET TRANSACTION READ ONLY;
SET SESSION TRANSACTION READ ONLY;
START TRANSACTION;
COMMIT;
SET TRANSACTION READ ONLY;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET SESSION TRANSACTION READ ONLY;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET SESSION TRANSACTION READ WRITE;
SET TRANSACTION READ ONLY;
START TRANSACTION READ WRITE;
ROLLBACK;
SET TRANSACTION READ ONLY;
START TRANSACTION;
COMMIT AND CHAIN;
ROLLBACK;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION READ ONLY;
ROLLBACK AND CHAIN;
COMMIT;
SET session_track_transaction_info="STATE";
START TRANSACTION WITH CONSISTENT SNAPSHOT;
COMMIT AND CHAIN;
COMMIT;
START TRANSACTION;
COMMIT AND CHAIN;
COMMIT;
START TRANSACTION WITH CONSISTENT SNAPSHOT;
START TRANSACTION WITH CONSISTENT SNAPSHOT;
COMMIT;
SET session_track_transaction_info="CHARACTERISTICS";
START TRANSACTION WITH CONSISTENT SNAPSHOT;
COMMIT AND CHAIN;
COMMIT;
START TRANSACTION;
COMMIT AND CHAIN;
COMMIT;
START TRANSACTION WITH CONSISTENT SNAPSHOT;
START TRANSACTION WITH CONSISTENT SNAPSHOT;
COMMIT;
CREATE TABLE t1 (f1 INT) ENGINE="InnoDB";
SET autocommit=0;
SET TRANSACTION READ ONLY;
INSERT INTO t1 VALUES(1);
ROLLBACK;
SET TRANSACTION READ WRITE;
