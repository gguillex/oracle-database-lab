-- scripts/lab5/06-propuesta-companero.sql — la propuesta del compañero (Q16): cinco índices más sobre PEDIDO "para que todo vaya rápido"
--   estado · canal · (id_cliente, fecha_pedido) · (fecha_pedido, id_cliente) · codigo_postal
-- Se ejecuta desde 06-indices.sh. Antes de crear, borra los restos de un intento anterior (se puede repetir sin limpiar a mano).
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 160 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
COLUMN index_name FORMAT A16
COLUMN columnas FORMAT A40
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
PROMPT
PROMPT ===== Propuesta del compañero: cinco índices nuevos sobre PEDIDO =====
CREATE INDEX tiendasur.ix_ped_estado ON tiendasur.pedido (estado);
CREATE INDEX tiendasur.ix_ped_canal ON tiendasur.pedido (canal);
CREATE INDEX tiendasur.ix_ped_cli_fec ON tiendasur.pedido (id_cliente, fecha_pedido);
CREATE INDEX tiendasur.ix_ped_fec_cli ON tiendasur.pedido (fecha_pedido, id_cliente);
CREATE INDEX tiendasur.ix_ped_cp ON tiendasur.pedido (codigo_postal);
SELECT i.index_name, LISTAGG(c.column_name, ', ') WITHIN GROUP (ORDER BY c.column_position) AS columnas, i.leaf_blocks AS hojas
  FROM dba_indexes i JOIN dba_ind_columns c ON c.index_owner = i.owner AND c.index_name = i.index_name
 WHERE i.owner = 'TIENDASUR' AND i.table_name = 'PEDIDO' GROUP BY i.index_name, i.leaf_blocks ORDER BY i.index_name;
EXIT
