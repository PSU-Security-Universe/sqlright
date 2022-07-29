create table v0(v1 int, v2 int, v3 char);
INSERT INTO V0 VALUES (10, 12, 'x');
INSERT INTO V0 VALUES (10, 12, 'x');
select v1 from v0 union select v2 from v0;
