-- scripts/lab4/08-reto-literales.sql — busca las sentencias que la aplicación ejecuta con literales en lugar de variables de enlace
SET LINESIZE 200 PAGESIZE 100
COLUMN ejemplo FORMAT A80
SELECT force_matching_signature,
       COUNT(*)               AS cursores,
       MIN(sql_text)          AS ejemplo
  FROM v$sql
 WHERE force_matching_signature <> 0
 GROUP BY force_matching_signature
HAVING COUNT(*) > 50
 ORDER BY cursores DESC;
EXIT
