SET default_storage_engine=archive;
CREATE TABLE gis_point  (fid INTEGER PRIMARY KEY AUTO_INCREMENT, g POINT);
SHOW CREATE TABLE gis_point;
INSERT INTO gis_point VALUES  (101, ST_PointFromText('POINT(10 10)')), (102, ST_PointFromText('POINT(20 10)')), (103, ST_PointFromText('POINT(20 20)')), (104, ST_PointFromWKB(ST_AsWKB(ST_PointFromText('POINT(10 20)'))));
ANALYZE TABLE gis_point;
ALTER TABLE t1 ADD fid INT;
create table t1 (pk integer primary key auto_increment, a geometry not null);
insert into t1 (a) values (ST_GeomFromText('Point(1 2)'));
