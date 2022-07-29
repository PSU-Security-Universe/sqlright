CREATE TABLE t1 (i INT PRIMARY KEY) ENGINE=MyISAM;
CREATE TABLE t2 (i INT PRIMARY KEY) ENGINE=MyISAM;
SET @save_table_open_cache= @@global.table_open_cache;
SET @@GLOBAL.table_open_cache=32;
SELECT * FROM t1;
SELECT * FROM t2;
SELECT CONVERT_TZ('2015-01-01 00:00:00', 'UTC', 'No-such-time-zone');
SET @@global.table_open_cache= @save_table_open_cache;
DROP TABLES t1, t2;
