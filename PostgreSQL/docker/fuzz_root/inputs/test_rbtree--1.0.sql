\echo Use "CREATE EXTENSION test_rbtree" to load this file. \quitCREATE FUNCTION test_rb_tree(size INTEGER)	RETURNS pg_catalog.void STRICT	AS 'MODULE_PATHNAME' LANGUAGE C;
