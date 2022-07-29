CREATE TABLE system_tables (ID INT PRIMARY KEY AUTO_INCREMENT, table_name VARCHAR(100));
INSERT INTO system_tables(table_name) SELECT UPPER(concat(table_schema, ".", table_name)) FROM INFORMATION_SCHEMA.tables WHERE table_schema = 'mysql' AND table_name NOT IN('general_log', 'slow_log', 'ndb_binlog_index') ORDER BY table_name;
CALL test_system_table_alter_engine();
DROP PROCEDURE test_system_table_alter_engine;
CREATE PROCEDURE execute_stmt(stmt VARCHAR(255)) BEGIN SET @error_no = 0; SET @sql_stmt = stmt; PREPARE stmt FROM @sql_stmt; EXECUTE stmt; GET DIAGNOSTICS CONDITION 1 @error_no = MYSQL_ERRNO, @error_message = MESSAGE_TEXT; IF @error_no > 0 THEN SELECT "Warning" AS SEVERITY, @error_no as ERRNO, @error_message as MESSAGE; END IF; DEALLOCATE PREPARE stmt; END;
CALL test_create_system_table();
DROP PROCEDURE test_create_system_table;
DROP PROCEDURE execute_stmt;
DROP TABLE system_tables;
