DROP TABLE IF EXISTS t1;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_as_cs;
SET @test_character_set= 'utf8mb4';
SET @test_collation= 'utf8mb4_0900_as_cs';
SET @safe_character_set_server= @@character_set_server;
SET @safe_collation_server= @@collation_server;
SET @safe_character_set_client= @@character_set_client;
SET @safe_character_set_results= @@character_set_results;
SET character_set_server= @test_character_set;
SET collation_server= @test_collation;
CREATE DATABASE d1;
USE d1;
CREATE TABLE t1 (c CHAR(10), KEY(c));
SHOW FULL COLUMNS FROM t1;
INSERT INTO t1 VALUES ('aaa'),('aaaa'),('aaaaa');
SELECT c as want3results FROM t1 WHERE c LIKE 'aaa%';
DROP TABLE t1;
CREATE TABLE t1 (c1 varchar(15), KEY c1 (c1(2)));
SHOW FULL COLUMNS FROM t1;
INSERT INTO t1 VALUES ('location'),('loberge'),('lotre'),('boabab');
SELECT c1 as want3results from t1 where c1 like 'l%';
SELECT c1 as want3results from t1 where c1 like 'lo%';
SELECT c1 as want1result  from t1 where c1 like 'loc%';
SELECT c1 as want1result  from t1 where c1 like 'loca%';
SELECT c1 as want1result  from t1 where c1 like 'locat%';
SELECT c1 as want1result  from t1 where c1 like 'locati%';
SELECT c1 as want1result  from t1 where c1 like 'locatio%';
SELECT c1 as want1result  from t1 where c1 like 'location%';
DROP TABLE t1;
create table t1 (a set('a') not null);
insert ignore into t1 values (),();
select cast(a as char(1)) from t1;
select a sounds like a from t1;
select 1 from t1 order by cast(a as char(1));
drop table t1;
set names utf8;
create table t1 ( name varchar(10), level smallint unsigned);
show create table t1;
insert into t1 values ('string',1);
select concat(name,space(level)), concat(name, repeat(' ',level)) from t1;
drop table t1;
DROP DATABASE d1;
USE test;
SET character_set_server= @safe_character_set_server;
SET collation_server= @safe_collation_server;
SET character_set_client= @safe_character_set_client;
SET character_set_results= @safe_character_set_results;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_as_cs;
create table t1 select repeat('a',4000) a;
delete from t1;
insert into t1 values ('a'), ('a '), ('a\t');
select collation(a),hex(a) from t1 order by a;
drop table t1;
create table t1 engine=innodb select repeat('a',50) as c1;
alter table t1 add index(c1(5));
insert into t1 values ('abcdefg'),('abcde100'),('abcde110'),('abcde111');
select collation(c1) from t1 limit 1;
select c1 from t1 where c1 like 'abcdef%' order by c1;
select c1 from t1 where c1 like 'abcde1%' order by c1;
select c1 from t1 where c1 like 'abcde11%' order by c1;
select c1 from t1 where c1 like 'abcde111%' order by c1;
drop table t1;
select @@collation_connection;
create table t1 ROW_FORMAT=DYNAMIC select repeat('a',50) as c1 ;
insert into t1 values('abcdef');
insert into t1 values('_bcdef');
insert into t1 values('a_cdef');
insert into t1 values('ab_def');
insert into t1 values('abc_ef');
insert into t1 values('abcd_f');
insert into t1 values('abcde_');
select c1 as c1u from t1 where c1 like 'ab\_def';
select c1 as c2h from t1 where c1 like 'ab#_def' escape '#';
drop table t1;
drop table if exists t1;
create table t1 select repeat('a',10) as c1;
delete from t1;
insert into t1 values (0x20),(0x21),(0x22),(0x23),(0x24),(0x25),(0x26),(0x27),(0x28),(0x29),(0x2A),(0x2B),(0x2C),(0x2D),(0x2E),(0x2F);
insert into t1 values (0x30),(0x31),(0x32),(0x33),(0x34),(0x35),(0x36),(0x37),(0x38),(0x39),(0x3A),(0x3B),(0x3C),(0x3D),(0x3E),(0x3F);
insert into t1 values (0x40),(0x41),(0x42),(0x43),(0x44),(0x45),(0x46),(0x47),(0x48),(0x49),(0x4A),(0x4B),(0x4C),(0x4D),(0x4E),(0x4F);
insert into t1 values (0x50),(0x51),(0x52),(0x53),(0x54),(0x55),(0x56),(0x57),(0x58),(0x59),(0x5A),(0x5B),(0x5C),(0x5D),(0x5E),(0x5F);
insert into t1 values (0x60),(0x61),(0x62),(0x63),(0x64),(0x65),(0x66),(0x67),(0x68),(0x69),(0x6A),(0x6B),(0x6C),(0x6D),(0x6E),(0x6F);
insert into t1 values (0x70),(0x71),(0x72),(0x73),(0x74),(0x75),(0x76),(0x77),(0x78),(0x79),(0x7A),(0x7B),(0x7C),(0x7D),(0x7E),(0x7F);
SELECT GROUP_CONCAT(c1 ORDER BY binary c1 SEPARATOR ''), GROUP_CONCAT(hex(c1) ORDER BY BINARY c1) FROM t1 GROUP BY c1;
drop table t1;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_as_cs;
SELECT HEX(CONVERT(_utf8mb4 0xF091AB9B41 USING ucs2));
SELECT HEX(CONVERT(_utf8mb4 0xF091AB9B41 USING utf16));
SELECT HEX(CONVERT(_utf8mb4 0xF091AB9B41 USING utf32));
SELECT HEX(CONVERT(_ucs2 0xF8FF USING utf8mb4));
SELECT HEX(CONVERT(_utf16 0xF8FF USING utf8mb4));
SELECT HEX(CONVERT(_utf32 0xF8FF USING utf8mb4));
SELECT HEX(CONVERT(_utf8mb4 0x8F USING ucs2));
SELECT HEX(CONVERT(_utf8mb4 0xC230 USING ucs2));
SELECT HEX(CONVERT(_utf8mb4 0xE234F1 USING ucs2));
SELECT HEX(CONVERT(_utf8mb4 0xF4E25634 USING ucs2));
SELECT ASCII('ABC');
SELECT BIT_LENGTH('a');
SELECT BIT_LENGTH('À');
SELECT BIT_LENGTH('テ');
SELECT BIT_LENGTH('𝌆');
SELECT CHAR_LENGTH('𝌆テÀa');
SELECT LENGTH('𝌆テÀa');
SELECT FIELD('a', '𝌆テÀa');
SELECT HEX('𝌆テÀa');
SELECT INSERT('𝌆テÀa', 2, 2, 'テb');
SELECT LOWER('𝌆テÀBcd');
SELECT ORD('𝌆');
SELECT UPPER('𝌆テàbCD');
SELECT LOCATE(_utf8mb4 0xF091AB9B41, _utf8mb4 0xF091AB9B42F091AB9B41F091AB9B43);
SELECT HEX(REVERSE(_utf8mb4 0xF091AB9B41F091AB9B42F091AB9B43));
SELECT HEX(SUBSTRING(_utf8mb4 0xF091AB9B41F091AB9B42F091AB9B43, 1, 2));
SELECT HEX(SUBSTRING(_utf8mb4 0xF091AB9B41F091AB9B42F091AB9B43, -3, 2));
SELECT HEX(TRIM(_utf8mb4 0x2020F091AB9B4120F091AB9B4120202020));
SELECT HEX(WEIGHT_STRING('aA'));
SELECT HEX(WEIGHT_STRING(CAST(_utf32 x'337F' AS CHAR)));
SELECT HEX(WEIGHT_STRING(CAST(_utf32 x'FDFA' AS CHAR)));
select @@collation_connection;
select hex(weight_string('a'));
select hex(weight_string('A'));
select hex(weight_string('abc'));
select hex(weight_string('abc' as char(2)));
