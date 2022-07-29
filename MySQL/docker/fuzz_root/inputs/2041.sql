TRUNCATE TABLE performance_schema.memory_summary_global_by_event_name;
CREATE SCHEMA dd_pfs;
DELETE FROM dd_pfs.mem_events WHERE Query = 'savepoint';
INSERT INTO dd_pfs.mem_events (Name, N_alloc, N_free, N_curr, Sz_alloc, Sz_free, Sz_curr, Query) SELECT EVENT_NAME AS Name, COUNT_ALLOC AS N_alloc, COUNT_FREE AS N_free, CURRENT_COUNT_USED AS N_curr, SUM_NUMBER_OF_BYTES_ALLOC AS Sz_alloc, SUM_NUMBER_OF_BYTES_FREE AS Sz_free, CURRENT_NUMBER_OF_BYTES_USED AS Sz_curr, 'savepoint' AS Query FROM performance_schema.memory_summary_global_by_event_name WHERE EVENT_NAME = 'memory/sql/dd::infrastructure' OR EVENT_NAME = 'memory/sql/dd::objects' OR EVENT_NAME = 'memory/sql/dd::String_type';
create schema s;
SET @diff = (SELECT COUNT_ALLOC - N_alloc FROM performance_schema.memory_summary_global_by_event_name, dd_pfs.mem_events WHERE EVENT_NAME = 'memory/sql/dd::objects' AND EVENT_NAME = Name AND Query = 'savepoint');
SET foreign_key_checks= 0;
FLUSH TABLES test.t_150;
