CREATE TABLE tinytbl (colA TINYINT UNSIGNED );
INSERT INTO tinytbl VALUES (0), (1), (0),(1),(3), (254), (255), (NULL);
ANALYZE TABLE tinytbl;
SELECT * FROM tinytbl;
SELECT * FROM tinytbl WHERE colA < 256;
SELECT * FROM tinytbl WHERE colA <= 255;
SELECT * FROM tinytbl WHERE colA > 256;
SELECT * FROM tinytbl WHERE colA >= 255;
SELECT * FROM tinytbl WHERE colA > -1;
PREPARE p_less    FROM 'SELECT * FROM tinytbl WHERE colA < ?';
SET @maxint_plus_1=256;
SET @maxint=255;
SET @minint_minus_1=-1;
SET @minint=0;
EXECUTE p_less    USING @maxint_plus_1;
DROP PREPARE p_less;
