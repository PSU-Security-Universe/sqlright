SELECT COUNT(*) AS must_be_zero_for_test FROM performance_schema.session_connect_attrs WHERE attr_name IN ('os_user', 'os_sudouser') AND PROCESSLIST_ID=CONNECTION_ID();
