PRAGMA encoding=UTF16le;
CREATE TABLE tkt3376(a COLLATE nocase PRIMARY KEY);
INSERT INTO tkt3376 VALUES('abc');
INSERT INTO tkt3376 VALUES('ABX');
SELECT DISTINCT a FROM tkt3376;
