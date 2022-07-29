INSTALL COMPONENT "file://component_test_backup_lock_service";
SELECT object_type, object_schema, object_name, lock_type, lock_duration, lock_status FROM performance_schema.metadata_locks WHERE object_type = 'BACKUP LOCK';
UNINSTALL COMPONENT "file://component_test_backup_lock_service";
SELECT object_schema, object_name, lock_type, lock_duration, lock_status FROM performance_schema.metadata_locks WHERE object_type = 'BACKUP LOCK';
INSTALL COMPONENT 'file://component_test_backup_lock_service';
INSTALL COMPONENT 'file://component_test_backup_lock_service';
SELECT object_schema, object_name, lock_type, lock_duration, lock_status FROM performance_schema.metadata_locks WHERE object_type = 'BACKUP LOCK';
UNINSTALL COMPONENT 'file://component_test_backup_lock_service';
