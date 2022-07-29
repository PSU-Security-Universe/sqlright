select pg_current_xact_id();
select length(pg_current_snapshot()::text) >= 4;
select pg_start_backup('should fail');
select pg_switch_wal();
select pg_stop_backup();
select * from pg_prepared_xacts;
select locktype, virtualxid, virtualtransaction, mode, grantedfrom pg_locks where virtualxid = '1/1';
select pg_cancel_backend(pg_backend_pid());
