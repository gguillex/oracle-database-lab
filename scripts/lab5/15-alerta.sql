-- scripts/lab5/15-alerta.sql — reto de la Parte P: devuelve UNA fila solo cuando hay que despertar a alguien (vacío = todo bien)
-- Pensada para un sistema de alertas: FRA por encima del 85 % o ninguna copia RMAN completada en las últimas 24 h.
-- Uso: bash scripts/ops/ro.sh scripts/lab5/15-alerta.sql
SET LINESIZE 170 PAGESIZE 100 FEEDBACK OFF
COLUMN alerta FORMAT A110
SELECT 'ALERTA: ' || LISTAGG(motivo, ' | ') WITHIN GROUP (ORDER BY motivo) AS alerta
  FROM (SELECT 'FRA al ' || ROUND(100 * space_used / space_limit, 1) || ' % (umbral 85 %)' AS motivo
          FROM v$recovery_file_dest WHERE space_limit > 0 AND space_used / space_limit > 0.85
        UNION ALL
        SELECT 'ninguna copia RMAN completada en 24 h' FROM dual
         WHERE NOT EXISTS (SELECT 1 FROM v$rman_backup_job_details WHERE status = 'COMPLETED' AND end_time > SYSDATE - 1))
HAVING COUNT(*) > 0;
PROMPT (Si no sale ninguna fila: no hay que despertar a nadie)
