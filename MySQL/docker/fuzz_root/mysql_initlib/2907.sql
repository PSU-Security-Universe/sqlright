CREATE USER test_user1;
CREATE USER test_user2;
FLUSH PRIVILEGES;
DROP USER test_user1, test_user2;
CREATE USER 'test#user1'@'localhost';
DROP USER 'test#user1'@'localhost';
CREATE USER 'test1 test1'@'localhost';
DROP USER 'test1 test1'@'localhost';
