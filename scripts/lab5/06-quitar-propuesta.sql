-- scripts/lab5/06-quitar-propuesta.sql — retira la propuesta del compañero tras el protocolo y deja PEDIDO como estaba "hoy"
-- Se ejecuta desde 06-indices.sh, antes de aplicar V005. Devuelve IX_PED_IMPORTE a VISIBLE (el protocolo lo dejó INVISIBLE en la
-- pregunta 5): retirarlo es decisión de V005, no de un experimento, y un índice invisible olvidado es un riesgo (verificación 16).
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 160 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
COLUMN index_name FORMAT A16
ALTER SESSION SET CONTAINER = FREEPDB1;
DECLARE
  PROCEDURE quitar(p_ddl VARCHAR2) IS BEGIN EXECUTE IMMEDIATE p_ddl; EXCEPTION WHEN OTHERS THEN NULL; END;
BEGIN
  quitar('DROP INDEX tiendasur.ix_ped_estado');
  quitar('DROP INDEX tiendasur.ix_ped_canal');
  quitar('DROP INDEX tiendasur.ix_ped_cli_fec');
  quitar('DROP INDEX tiendasur.ix_ped_fec_cli');
  quitar('DROP INDEX tiendasur.ix_ped_cp');
END;
/
ALTER INDEX tiendasur.ix_ped_importe VISIBLE;
PROMPT
PROMPT ===== Propuesta retirada: PEDIDO vuelve a sus índices de partida, todos visibles =====
SELECT index_name, visibility FROM dba_indexes WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO' ORDER BY index_name;
EXIT
