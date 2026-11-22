-- database/migrations/V006__ix_cli_telefono.sql
-- Propuesta (reto de la Parte G del Lab 5): índice para Q5, identificar a quien llama al centro de atención por email O teléfono.
-- Protocolo de cinco preguntas, con las cifras medidas en el reto de la Parte G (docs/bitacora/lab5-respuestas.md):
--   1 Necesidad     Q5 lee 1486 bloques (recorrido completo): la rama del teléfono no tiene índice y el OR no puede usar UX_CLI_EMAIL solo
--   2 Viabilidad    99 952 teléfonos distintos en 100 000 clientes: 0,001 % por valor, muy por debajo del umbral
--   3 Escritura     INSERT de cliente: 10,3 -> 12,1 bloques modificados por fila y 1462 -> 1644 bytes de redo
--   4 Redundancia   ningún índice de CLIENTE empieza por telefono
--   5 Ciclo de vida con el índice, Q5 lee 6 bloques (BITMAP OR con UX_CLI_EMAIL). Si en la observación no se usa: INVISIBLE y retirar
-- Idempotente: si ix_cli_telefono ya existe, no hace nada.
SET FEEDBACK ON
ALTER SESSION SET CONTAINER = FREEPDB1;
WHENEVER SQLERROR EXIT SUCCESS
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_indexes WHERE owner = 'TIENDASUR' AND index_name = 'IX_CLI_TELEFONO';
  IF n > 0 THEN RAISE_APPLICATION_ERROR(-20006, 'V006 ya aplicada: IX_CLI_TELEFONO existe, no se hace nada'); END IF;
END;
/
WHENEVER SQLERROR EXIT SQL.SQLCODE
CREATE INDEX tiendasur.ix_cli_telefono ON tiendasur.cliente (telefono) ONLINE;
SET LINESIZE 150 PAGESIZE 50
COLUMN index_name FORMAT A20
SELECT index_name, uniqueness, visibility FROM dba_indexes WHERE owner = 'TIENDASUR' AND table_name = 'CLIENTE' ORDER BY index_name;
EXIT
