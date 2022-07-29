CREATE DATABASE test_user_db;
CREATE USER qa_test_11_user IDENTIFIED WITH qa_auth_server AS 'qa_test_11_dest';
CREATE USER qa_test_11_dest identified by 'dest_passwd';
GRANT ALL PRIVILEGES ON test_user_db.* TO qa_test_11_dest;
GRANT PROXY ON qa_test_11_dest TO qa_test_11_user;
DROP USER qa_test_11_user, qa_test_11_dest;
DROP DATABASE test_user_db;
