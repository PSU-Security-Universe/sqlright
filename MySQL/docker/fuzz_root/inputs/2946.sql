CREATE DATABASE test_zone;
USE test_zone;
START TRANSACTION;
INSERT INTO time_zone (Use_leap_seconds) VALUES ('N');
SET @time_zone_id= LAST_INSERT_ID();
COMMIT;
TRUNCATE TABLE time_zone_leap_second;
