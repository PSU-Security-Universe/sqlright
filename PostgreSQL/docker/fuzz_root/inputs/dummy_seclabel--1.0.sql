\echo Use "CREATE EXTENSION dummy_seclabel" to load this file. \quitCREATE FUNCTION dummy_seclabel_dummy()   RETURNS pg_catalog.void       AS 'MODULE_PATHNAME' LANGUAGE C;
