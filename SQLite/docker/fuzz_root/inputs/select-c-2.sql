CREATE TABLE person (org_id TEXT NOT NULL, nickname        TEXT NOT NULL, license         TEXT, CONSTRAINT person_pk PRIMARY KEY (org_id, nickname), CONSTRAINT person_license_uk UNIQUE (license) );
INSERT INTO person VALUES('meyers', 'jack', '2GAT123');
INSERT INTO person VALUES('meyers', 'hill', 'V345FMP');
INSERT INTO person VALUES('meyers', 'jim', '2GAT138');
INSERT INTO person VALUES('smith', 'maggy', '');
CREATE TABLE t2(a PRIMARY KEY, b);
INSERT INTO t2 VALUES('abc', 'xxx');
INSERT INTO t2 VALUES('def', 'yyy');
SELECT org_id, count((NOT (org_id IS NULL)) AND (NOT (nickname IS NULL))) FROM person WHERE (CASE WHEN license != '' THEN 1 ELSE 0 END) GROUP BY 1;
SELECT a, max(b || a) FROM t2 WHERE (b||b||b)!='value' GROUP BY a;

