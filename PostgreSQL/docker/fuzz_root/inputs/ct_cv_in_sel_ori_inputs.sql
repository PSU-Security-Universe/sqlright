create table v0(v1 int ,v2 int);
create view v2 as select v1, v2 from v0;
insert into v2 values(1, 1);
INSERT INTO V0 VALUES (0, 0);
INSERT INTO V0 VALUES (0, 0);
INSERT INTO V0 VALUES (0, 0);
select v1 from v2;
