#!/usr/bin/env bash
# =====================================================================
# Respaldo y restauración de la base de datos (RNF-05).
#
#   herramientas/respaldo.sh                 # crea respaldos/sanfelipe_AAAAMMDD_HHMMSS.sql.gz
#   herramientas/respaldo.sh restaurar ARCHIVO.sql.gz
#
# Para el respaldo diario automático, prográmelo en cron (Linux) o en el
# Programador de tareas (Windows), por ejemplo a las 23:30:
#   30 23 * * * cd /ruta/al/repositorio && herramientas/respaldo.sh
# La carpeta respaldos/ está en .gitignore: contiene datos personales.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
set -a
# shellcheck disable=SC1091
source .env
set +a

if [[ "${1:-}" == "restaurar" ]]; then
  archivo="${2:?Indique el archivo .sql.gz a restaurar}"
  echo "Restaurando ${archivo} en ${DB_NAME}…"
  gunzip -c "${archivo}" | docker compose exec -T basedatos \
    sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
  echo "Listo."
  exit 0
fi

mkdir -p respaldos
destino="respaldos/${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql.gz"
# --single-transaction: copia coherente sin bloquear la operación (InnoDB).
docker compose exec -T basedatos sh -c \
  'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers "$MYSQL_DATABASE"' \
  | gzip > "${destino}"
echo "Respaldo creado: ${destino} ($(du -h "${destino}" | cut -f1))"
