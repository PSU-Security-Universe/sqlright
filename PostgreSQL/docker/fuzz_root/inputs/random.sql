SELECT count(*) FROM onek;
(SELECT unique1 AS random  FROM onek ORDER BY random() LIMIT 1)INTERSECT(SELECT unique1 AS random  FROM onek ORDER BY random() LIMIT 1)INTERSECT(SELECT unique1 AS random  FROM onek ORDER BY random() LIMIT 1);
SELECT count(*) AS random INTO RANDOM_TBL  FROM onek WHERE random() < 1.0/10;
INSERT INTO RANDOM_TBL (random)  SELECT count(*)  FROM onek WHERE random() < 1.0/10;
INSERT INTO RANDOM_TBL (random)  SELECT count(*)  FROM onek WHERE random() < 1.0/10;
INSERT INTO RANDOM_TBL (random)  SELECT count(*)  FROM onek WHERE random() < 1.0/10;
SELECT random, count(random) FROM RANDOM_TBL  GROUP BY random HAVING count(random) > 3;
SELECT AVG(random) FROM RANDOM_TBL  HAVING AVG(random) NOT BETWEEN 80 AND 120;
