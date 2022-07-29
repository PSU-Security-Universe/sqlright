SET SESSION DEFAULT_STORAGE_ENGINE = MyISAM;
create table t0 ( key1 int not null, key2 int not null, key3 int not null, key4 int not null, key5 int not null, key6 int not null, key7 int not null, key8 int not null, INDEX i1(key1), INDEX i2(key2), INDEX i3(key3), INDEX i4(key4), INDEX i5(key5), INDEX i6(key6), INDEX i7(key7), INDEX i8(key8) );
insert into t0 values (1,1,1,1,1,1,1,1023),(2,2,2,2,2,2,2,1022);
set @d=2;
analyze table t0;
alter table t2 add index i1_3(key1, key3);
update t3 set key9=key1,keyA=key1,keyB=key1,keyC=key1;
delete from t0 where key1 < 3 or key2 < 4;
set join_buffer_size= 4096;
