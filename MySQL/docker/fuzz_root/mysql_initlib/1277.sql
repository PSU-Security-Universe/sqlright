CREATE DATABASE b12688860_db;
CREATE TABLE b12688860_db.b12688860_tab (c1 INT);
SELECT * FROM b12688860_db.b12688860_tab;
DROP TABLE b12688860_db.b12688860_tab;
DROP DATABASE b12688860_db;
CREATE USER 'user_with_length_32_abcdefghijkl'@'localhost';
GRANT ALL ON *.* TO 'user_with_length_32_abcdefghijkl'@'localhost';
DROP TABLE mysql.test;
DROP USER 'user_with_length_32_abcdefghijkl'@'localhost';
