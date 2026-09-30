#!/usr/bin/env bash
# scripts/deployment/env/06-verificar-conexion.sh

source scripts/deployment/env/00-config.sh

echo "== Estado de salud del contenedor =="
docker inspect --format='{{.State.Health.Status}}' "$CONT_NAME"
echo

echo "== Prueba de conexión SQL =="
docker exec -i "$CONT_NAME" sqlplus -s sys/"$ORACLE_PWD"@localhost:1521/"$SERVICE_PDB" as sysdba << SQL
SET HEADING ON
SET PAGESIZE 100
COLUMN name FORMAT A15
COLUMN open_mode FORMAT A15
SELECT name, open_mode FROM v\$pdbs;
EXIT;
SQL
