CREATE ROLE r1, r2;
SET ROLE r1;
SET GLOBAL binlog_cache_size=100;
SET GLOBAL binlog_cache_size=DEFAULT;
SET ROLE r2;
SET GLOBAL binlog_cache_size=100;
DROP ROLE r2,r1;
