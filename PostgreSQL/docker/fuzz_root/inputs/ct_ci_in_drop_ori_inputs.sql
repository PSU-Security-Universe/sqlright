create table v0(v1 int);
insert into v0 values(1);
insert into v0 values(1);
insert into v0 values(1);
insert into v0 values(1);
insert into v0 values(1);
update v0 set v1 = 1 where v1 = 3; select v1 from v0;
