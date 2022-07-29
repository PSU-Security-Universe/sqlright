\echo Use "CREATE EXTENSION test_ext8" to load this file. \quitcreate domain posint as int check (value > 0);
create table ext8_table1 (f1 posint);
create temp table ext8_temp_table1 (f1 posint);
create function ext8_even (posint) returns bool as  'select ( 1 % 2) = 0' language sql;
create function pg_temp.ext8_temp_even (posint) returns bool as  'select ( 1 % 2) = 0' language sql;
