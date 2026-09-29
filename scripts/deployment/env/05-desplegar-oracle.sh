#!/usr/bin/env bash
# scripts/deployment/env/05-desplegar-oracle.sh

source scripts/deployment/env/00-config.sh

echo "== Creando volumen de persistencia =="
docker volume create "$VOL_NAME"
echo

echo "== Desplegando contenedor de Oracle =="
docker run -d \
  --name "$CONT_NAME" \
  -p "$PORT_DB":1521 \
  -e ORACLE_PWD="$ORACLE_PWD" \
  -e APP_USER_PWD="$APP_USER_PWD" \
  -v "$VOL_NAME":/opt/oracle/oradata \
  "$IMG"
echo

echo "== Estado inicial del contenedor =="
docker ps -f name="$CONT_NAME"
