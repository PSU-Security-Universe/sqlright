CREATE USER 'empl_external'@'localhost' IDENTIFIED WITH test_plugin_server AS 'employee';
CREATE USER 'employee'@'localhost' IDENTIFIED BY 'passkey';
GRANT PROXY ON 'employee'@'localhost' TO 'empl_external'@'localhost';
SELECT USER(), CURRENT_USER();
DROP USER 'empl_external'@'localhost', 'employee'@'localhost';
