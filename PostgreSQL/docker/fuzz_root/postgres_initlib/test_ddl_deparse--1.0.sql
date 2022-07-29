\echo Use "CREATE EXTENSION test_ddl_deparse" to load this file. \quitCREATE FUNCTION get_command_type(pg_ddl_command)  RETURNS text IMMUTABLE STRICT  AS 'MODULE_PATHNAME' LANGUAGE C;
CREATE FUNCTION get_command_tag(pg_ddl_command)  RETURNS text IMMUTABLE STRICT  AS 'MODULE_PATHNAME' LANGUAGE C;
CREATE FUNCTION get_altertable_subcmdtypes(pg_ddl_command)  RETURNS text[] IMMUTABLE STRICT  AS 'MODULE_PATHNAME' LANGUAGE C;
