\echo Use "CREATE EXTENSION dummy_index_am" to load this file. \quitCREATE FUNCTION dihandler(internal)RETURNS index_am_handlerAS 'MODULE_PATHNAME'LANGUAGE C;
CREATE ACCESS METHOD dummy_index_am TYPE INDEX HANDLER dihandler;
COMMENT ON ACCESS METHOD dummy_index_am IS 'dummy index access method';
CREATE OPERATOR CLASS int4_opsDEFAULT FOR TYPE int4 USING dummy_index_am AS  OPERATOR 1 = (int4, int4),  FUNCTION 1 hashint4(int4);
