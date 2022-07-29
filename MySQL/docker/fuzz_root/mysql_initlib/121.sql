INSTALL PLUGIN test_udf_services SONAME 'test_udf_services.so';
CREATE FUNCTION test_udf_services_udf RETURNS INT SONAME "test_udf_services.so";
UNINSTALL PLUGIN test_udf_services;
INSTALL PLUGIN test_udf_services SONAME 'test_udf_services.so';
DROP FUNCTION test_udf_services_udf;
UNINSTALL PLUGIN test_udf_services;
