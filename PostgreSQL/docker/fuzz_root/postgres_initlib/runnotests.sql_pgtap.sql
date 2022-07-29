\unset ECHO\i test/setup.sqlSET client_min_messages = warning;
CREATE SCHEMA whatever;
CREATE OR REPLACE FUNCTION whatever.testthis() RETURNS SETOF TEXT AS $$BEGIN    END;
$$ LANGUAGE plpgsql;
SELECT * FROM runtests('whatever'::name);
ROLLBACK;
