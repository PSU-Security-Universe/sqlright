SET @@tmpdir= 'no/such/directory';
SET @@innodb_tmpdir= NULL;
CREATE TABLE test.t(a text);
ALTER TABLE test.t ADD fulltext(a);
DROP TABLE test.t;
