DROP TABLE IF EXISTS t1,t2,t3;
CREATE TABLE t1(c1 DOUBLE, c2 DOUBLE, c3 DOUBLE, c4 DOUBLE, c5 DOUBLE, c6 DOUBLE, c7 DOUBLE, c8 DOUBLE, c9 DOUBLE, a INT PRIMARY KEY);
FLUSH TABLES;
CHECK TABLE t1 EXTENDED;
DROP TABLE t1;
drop table if exists t1;
create table t1(f1 int, f2 char(255));
insert into t1 values(1, 'foo'), (2, 'bar');
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
insert into t1 select * from t1;
flush tables;
optimize table t1;
repair table t1;
drop table t1;
CREATE TABLE  t1(f1 VARCHAR(200), f2 TEXT);
INSERT INTO  t1 VALUES ('foo', 'foo1'), ('bar', 'bar1');
INSERT INTO t1 SELECT * FROM t1;
INSERT INTO t1 SELECT * FROM t1;
INSERT INTO t1 SELECT * FROM t1;
INSERT INTO t1 SELECT * FROM t1;
INSERT INTO t1 SELECT * FROM t1;
INSERT INTO t1 SELECT * FROM t1;
INSERT INTO t1 SELECT * FROM t1;
INSERT INTO t1 SELECT * FROM t1;
INSERT INTO t1 SELECT * FROM t1;
FLUSH TABLE t1;
SELECT COUNT(*) FROM t1;
DROP TABLE t1;
CREATE DATABASE mysql_db1;
CREATE TABLE mysql_db1.t1 (c1 VARCHAR(5), c2 int);
CREATE INDEX i1 ON mysql_db1.t1 (c1, c2);
INSERT INTO mysql_db1.t1 VALUES ('A',1);
INSERT INTO mysql_db1.t1 SELECT * FROM mysql_db1.t1;
INSERT INTO mysql_db1.t1 SELECT * FROM mysql_db1.t1;
INSERT INTO mysql_db1.t1 SELECT * FROM mysql_db1.t1;
INSERT INTO mysql_db1.t1 SELECT * FROM mysql_db1.t1;
INSERT INTO mysql_db1.t1 SELECT * FROM mysql_db1.t1;
INSERT INTO mysql_db1.t1 SELECT * FROM mysql_db1.t1;
INSERT INTO mysql_db1.t1 SELECT * FROM mysql_db1.t1;
FLUSH TABLE mysql_db1.t1;
SELECT COUNT(*) FROM mysql_db1.t1 WHERE c2 < 5;
DROP DATABASE mysql_db1;
CREATE TABLE t1(a CHAR(4), FULLTEXT(a));
INSERT INTO t1 VALUES('aaaa'),('bbbb'),('cccc');
FLUSH TABLE t1;
CHECK TABLE t1;
SELECT * FROM t1 WHERE MATCH(a) AGAINST('aaaa' IN BOOLEAN MODE);
SELECT * FROM t1 WHERE MATCH(a) AGAINST('aaaa');
DROP TABLE t1;
CREATE TABLE t1(a CHAR(30), FULLTEXT(a));
INSERT INTO t1 VALUES('1700aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1699aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1698aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1697aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1696aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1695aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1694aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1693aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1692aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1691aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1690aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1689aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1688aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1687aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1686aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1685aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1684aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1683aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1682aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1681aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1680aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1679aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1678aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1677aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1676aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1675aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1674aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1673aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1672aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1671aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1670aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1669aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1668aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1667aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1666aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1665aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1664aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1663aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1662aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1661aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1660aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1659aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1658aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1657aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1656aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1655aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1654aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1653aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1652aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1651aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1650aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1649aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1648aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1647aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1646aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1645aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1644aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1643aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1642aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1641aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1640aaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO t1 VALUES('1639aaaaaaaaaaaaaaaaaaaaaaaaaa');