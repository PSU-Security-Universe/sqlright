ALTER INSTANCE RELOAD TLS;
SET @orig_ssl_ca= @@global.ssl_ca;
SET GLOBAL ssl_ca = 'gizmo';
ALTER INSTANCE RELOAD TLS NO ROLLBACK ON ERROR;
SET GLOBAL ssl_ca = @orig_ssl_ca;
