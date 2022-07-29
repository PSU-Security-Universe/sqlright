CREATE VIRTUAL TABLE rt0 USING rtree(c0, c1, c2);
CREATE VIRTUAL TABLE rt1 USING rtree(c0, c1, c2);
INSERT INTO rt0(c0) VALUES (x'');
INSERT INTO rt1(c0) VALUES (1);

SELECT * FROM rt1 RIGHT OUTER JOIN rt0 ON rt1.c0;
SELECT * FROM rt1 RIGHT OUTER JOIN rt0 ON rt1.c0 WHERE ((rt1.c1) NOT NULL)==rt0.c0;
SELECT * FROM rt1 RIGHT OUTER JOIN rt0 ON rt1.c0 WHERE ((rt1.c1) NOT NULL)!=rt0.c0;
