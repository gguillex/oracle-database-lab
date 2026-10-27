-- scripts/lab5/01-perfil-tiendasur.sql — el banco TiendaSur descrito con números: filas, bloques, bfr y sesgos
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>. Solo lee.
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 170 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
COLUMN table_name FORMAT A8
COLUMN column_name FORMAT A14
COLUMN histogram FORMAT A16
COLUMN dato FORMAT A30
COLUMN last_analyzed FORMAT A12
ALTER SESSION SET CONTAINER = FREEPDB1;
PROMPT
PROMPT ===== 1. Tablas: r filas, b bloques, R bytes por fila y bfr = r / b =====
SELECT t.table_name, t.num_rows AS r, t.blocks AS b, t.avg_row_len AS r_bytes, ROUND(t.num_rows / t.blocks) AS bfr,
       ROUND(s.bytes / 1048576, 1) AS mb, TO_CHAR(t.last_analyzed, 'YYYY-MM-DD') AS last_analyzed
  FROM dba_tables t JOIN dba_segments s ON s.owner = t.owner AND s.segment_name = t.table_name
 WHERE t.owner = 'TIENDASUR' ORDER BY t.table_name;
PROMPT (b = ceil(r / bfr): bfr es una MEDIA, cada bloque tiene más o menos filas según el tamaño de cada una)
PROMPT
PROMPT ===== 2. Columnas con histograma: el optimizador conoce la distribución real =====
SELECT table_name, column_name, num_distinct, histogram, num_buckets
  FROM dba_tab_col_statistics WHERE owner = 'TIENDASUR' AND histogram <> 'NONE' ORDER BY table_name, column_name;
PROMPT
PROMPT ===== 3. Los sesgos que dan juego a las consultas Q1-Q16 =====
SELECT 'cliente pais = ES' AS dato, ROUND(100 * AVG(CASE WHEN pais = 'ES' THEN 1 ELSE 0 END), 1) AS pct FROM tiendasur.cliente
UNION ALL SELECT 'cliente ciudad = Lorca', ROUND(100 * AVG(CASE WHEN ciudad = 'Lorca' THEN 1 ELSE 0 END), 1) FROM tiendasur.cliente
UNION ALL SELECT 'cliente apellidos LIKE Gonz%', ROUND(100 * AVG(CASE WHEN apellidos LIKE 'Gonz%' THEN 1 ELSE 0 END), 1) FROM tiendasur.cliente
UNION ALL SELECT 'pedido estado = P', ROUND(100 * AVG(CASE WHEN estado = 'P' THEN 1 ELSE 0 END), 1) FROM tiendasur.pedido;
PROMPT
PROMPT ===== 4. Reparto de estados y canales del pedido =====
SELECT estado, COUNT(*) AS pedidos, ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 1) AS pct FROM tiendasur.pedido GROUP BY estado ORDER BY estado;
SELECT canal, COUNT(*) AS pedidos, ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 1) AS pct FROM tiendasur.pedido GROUP BY canal ORDER BY canal;
PROMPT
PROMPT ===== 5. Rango de fechas (tres años hasta el día de la migración) y pedidos por cliente =====
SELECT TO_CHAR(MIN(fecha_pedido), 'YYYY-MM-DD') AS primera, TO_CHAR(MAX(fecha_pedido), 'YYYY-MM-DD') AS ultima,
       COUNT(DISTINCT id_cliente) AS clientes_con_pedido, ROUND(COUNT(*) / COUNT(DISTINCT id_cliente), 1) AS pedidos_por_cliente
  FROM tiendasur.pedido;
EXIT
