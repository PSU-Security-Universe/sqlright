\echo Use "CREATE EXTENSION test_event_trigger" to load this file. \quitCREATE TABLE t (id text);
CREATE OR REPLACE FUNCTION _evt_table_rewrite_fnct()RETURNS EVENT_TRIGGER LANGUAGE plpgsql AS  BEGIN  END;
;
CREATE EVENT TRIGGER table_rewrite_trg  ON table_rewrite  EXECUTE PROCEDURE _evt_table_rewrite_fnct();
