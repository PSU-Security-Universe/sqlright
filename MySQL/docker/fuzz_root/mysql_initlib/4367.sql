SET PERSIST_ONLY ssl_ca = 'mohit';
SELECT @@global.ssl_ca;
SHOW STATUS LIKE '%tls_ca';
SHOW STATUS LIKE 'ssl_cipher';
RESET PERSIST;
