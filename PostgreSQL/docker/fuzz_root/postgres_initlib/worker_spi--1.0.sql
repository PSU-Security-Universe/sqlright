\echo Use "CREATE EXTENSION worker_spi" to load this file. \quitCREATE FUNCTION worker_spi_launch(pg_catalog.int4)RETURNS pg_catalog.int4 STRICTAS 'MODULE_PATHNAME'LANGUAGE C;
