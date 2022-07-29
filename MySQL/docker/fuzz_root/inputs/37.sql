CREATE FUNCTION service_get_read_locks  RETURNS INT SONAME "locking_service.so";
UPDATE performance_schema.setup_instruments SET enabled = 'NO', timed = 'YES';
TRUNCATE TABLE performance_schema.events_waits_current;
