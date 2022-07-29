SET @sql_log_bin_save = @@sql_log_bin;
SET SESSION sql_log_bin = 0;
SET SESSION sql_require_primary_key = 0;
USE test;
CREATE TEMPORARY TABLE file_tbl (filename varchar(1024));
SET @@sql_log_bin = @sql_log_bin_save;
