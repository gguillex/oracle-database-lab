-- scripts/lab5/17-revision-v006.sql — revisión de V006 (ix_cli_telefono) antes de fusionarla
-- Se ejecuta como SYSDBA antes y después de aplicar V006: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
-- Mide Q5 (identificar a quien llama por email O teléfono) con un cliente real y mira el coste del alta de un cliente.
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON FORMAT WRAPPED
COLUMN index_name FORMAT A20
COLUMN tel NEW_VALUE tel NOPRINT
PROMPT == 1. Índices de CLIENTE en este momento ==
SELECT index_name, uniqueness, visibility FROM dba_indexes WHERE owner = 'TIENDASUR' AND table_name = 'CLIENTE' ORDER BY index_name;
PROMPT == 2. Un teléfono real para la prueba (el del cliente 4242) ==
SELECT telefono AS tel FROM tiendasur.cliente WHERE id_cliente = 4242;
PROMPT == 3. Q5: lectura ==
EXEC lab_tools.medir.consulta('Q5 email o telefono', q'[SELECT * FROM tiendasur.cliente WHERE email = '&tel' OR telefono = '&tel']')
PROMPT == 4. Coste de escritura: 1000 altas de cliente (se deshacen al medir) ==
EXEC lab_tools.medir.dml('1000 altas de cliente', q'[BEGIN FOR i IN 1 .. 1000 LOOP INSERT INTO tiendasur.cliente (id_cliente, dni, email, nombre, apellidos, telefono, pais, ciudad, fecha_alta) VALUES (900000 + i, LPAD(90000000 + i, 8, '0') || 'X', 'rev' || i || '@v006.test', 'Prueba', 'Revision', TO_CHAR(690000000 + i), 'ES', 'Murcia', SYSDATE); END LOOP; END;]', 1000)
EXIT
