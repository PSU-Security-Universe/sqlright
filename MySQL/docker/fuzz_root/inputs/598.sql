SET sql_mode = 'ONLY_FULL_GROUP_BY,NO_ENGINE_SUBSTITUTION';
CREATE TABLE gis_point (fid INTEGER NOT NULL PRIMARY KEY, g POINT);
SHOW FIELDS FROM gis_point;
INSERT INTO gis_point VALUES  (101, ST_PointFromText('POINT(10 10)')), (102, ST_PointFromText('POINT(20 10)')), (103, ST_PointFromText('POINT(20 20)')), (104, ST_PointFromWKB(ST_AsWKB(ST_PointFromText('POINT(10 20)'))));
ALTER TABLE t1 ADD fid INT NOT NULL;
create table t1 (a geometry not null SRID 0);
insert into t1 values (ST_GeomFromText('Point(1 2)'));
alter table t1 add spatial index(a);
