create table v0(v1 FLOAT);
create view v2 AS select * from v0;
INSERT INTO V0 VALUES (10.0);
select * from v2;
