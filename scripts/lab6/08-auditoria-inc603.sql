-- scripts/lab6/08-auditoria-inc603.sql — ¿quién bloqueó APP_ACADEMIA y cuándo? (INC-603, paso 4: confirmar la hipótesis)
-- SYSDBA: bash scripts/ops/sysdba.sh scripts/lab6/08-auditoria-inc603.sql "$EVID_LAB6/script/$(ts)_08-auditoria-inc603.script.log"
-- Solo lectura. Consulta declarada en docs/bitacora/lab6-ia.md (entrada 1).
SET LINESIZE 200 PAGESIZE 50 FEEDBACK ON
ALTER SESSION SET CONTAINER = FREEPDB1;
COLUMN event_timestamp FORMAT A28
COLUMN dbusername FORMAT A10
COLUMN os_username FORMAT A10
COLUMN client_program_name FORMAT A30
COLUMN action_name FORMAT A10
COLUMN sql_text FORMAT A60
SELECT event_timestamp, dbusername, os_username, client_program_name, action_name, sql_text
  FROM unified_audit_trail
 WHERE action_name = 'ALTER USER' AND UPPER(sql_text) LIKE '%APP_ACADEMIA%'
 ORDER BY event_timestamp DESC FETCH FIRST 5 ROWS ONLY;
EXIT
