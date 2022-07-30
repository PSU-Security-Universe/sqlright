\echo Use "CREATE EXTENSION test_parser" to load this file. \quitCREATE FUNCTION testprs_start(internal, int4)RETURNS internalAS 'MODULE_PATHNAME'LANGUAGE C STRICT;
CREATE FUNCTION testprs_getlexeme(internal, internal, internal)RETURNS internalAS 'MODULE_PATHNAME'LANGUAGE C STRICT;
CREATE FUNCTION testprs_end(internal)RETURNS voidAS 'MODULE_PATHNAME'LANGUAGE C STRICT;
CREATE FUNCTION testprs_lextype(internal)RETURNS internalAS 'MODULE_PATHNAME'LANGUAGE C STRICT;
CREATE TEXT SEARCH PARSER testparser (    START    = testprs_start,    GETTOKEN = testprs_getlexeme,    END      = testprs_end,    HEADLINE = pg_catalog.prsd_headline,    LEXTYPES = testprs_lextype);
