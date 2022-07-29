SELECT CONNECTION_ID() INTO @id1;
SELECT MAX(processlist_id) FROM performance_schema.threads INTO @id2;
SELECT variable_value FROM performance_schema.global_status WHERE variable_name='connections' INTO @id3;
SELECT (@id1=@id2);
SELECT (@id2=@id3);
SET @id4=17;
SELECT (@id3=@id4);
