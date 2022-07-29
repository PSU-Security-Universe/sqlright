SET SQL_WARNINGS=1;
SET sql_mode = 'NO_ENGINE_SUBSTITUTION';
CREATE TABLE t1 ( id int(11) NOT NULL auto_increment, datatype_id int(11) DEFAULT '0' NOT NULL, min_value decimal(20,10) DEFAULT '0.0000000000' NOT NULL, max_value decimal(20,10) DEFAULT '0.0000000000' NOT NULL, valuename varchar(20), forecolor int(11), backcolor int(11), PRIMARY KEY (id), UNIQUE datatype_id (datatype_id, min_value, max_value) );
set names latin1;
INSERT INTO t1 VALUES ( '1', '4', '0.0000000000', '0.0000000000', 'Ei saja', '0', '16776960');
