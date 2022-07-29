INSTALL PLUGIN example SONAME 'ha_example.so';
SELECT PLUGIN_STATUS FROM INFORMATION_SCHEMA.plugins WHERE plugin_name='example';
INSTALL PLUGIN example SONAME 'ha_example.so';
UNINSTALL PLUGIN example;
