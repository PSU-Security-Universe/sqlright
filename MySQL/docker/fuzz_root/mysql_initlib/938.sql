SET @sql_log_bin_save = @@sql_log_bin;
SET SESSION sql_log_bin = 0;
SET SESSION sql_require_primary_key = 0;
USE test;
CREATE TEMPORARY TABLE file_tbl (filename varchar(1024));
LOAD DATA INFILE '/dev/shm/var_auto_6XVJ/file_list_1.flist' INTO TABLE file_tbl;
SELECT filename FROM file_tbl WHERE filename NOT LIKE 'check-mysqld_%'       AND filename NOT LIKE 'mysql%.sock%'       AND filename NOT LIKE 'file_list_%.flist'       AND filename NOT LIKE 'mysqld%.expect'       AND filename NOT LIKE 'bootstrap.log'       AND filename NOT LIKE 'test_%.log';
DROP TABLE test.file_tbl;
SET @@sql_log_bin = @sql_log_bin_save;
