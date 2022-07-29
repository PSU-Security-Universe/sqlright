CREATE TABLE abs( col1 int not null, col2 int not null, col3 varchar(10), CONSTRAINT pk PRIMARY KEY (col1, col2) ) ENGINE InnoDb;
SHOW CREATE TABLE abs;
