#!/usr/bin/env bash
# =====================================================================
# P-18b (RNF-05): mide la restauración completa de un respaldo de la base
# de datos del prototipo, con herramientas/respaldo.sh.
#
#   herramientas/medir_restauracion.sh                 # base con datos_ejemplo.sql
#   FILAS_BITACORA=200000 herramientas/medir_restauracion.sh   # más volumen sintético
#
# Usa un proyecto de docker compose aparte (sfp18b), con su propio volumen y
# contraseñas aleatorias que no se guardan, en el puerto 127.0.0.1:33307: no
# toca la base de desarrollo. Pasos: 1) base nueva con esquema.sql y
# datos_ejemplo.sql (y, si se pide, filas sintéticas de bitácora); 2) una
# fila marcadora; 3) suma de verificación (CHECKSUM TABLE) y conteo de cada
# tabla; 4) respaldo con respaldo.sh; 5) pérdida simulada: se borra el
# contenedor y su volumen; 6) desde ese momento se mide: base nueva,
# restauración con «respaldo.sh restaurar» y nueva suma de verificación;
# 7) se comparan las sumas. Escribe docs/evidencias/p18b/restauracion_<fecha>.md.
# Datos de ejemplo ficticios; el respaldo se borra al terminar.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
PROYECTO=sfp18b
ENVF="$(mktemp)"
fecha="$(date -u +%Y%m%dT%H%M%SZ)"
salida="docs/evidencias/p18b/restauracion_${fecha}.md"
clave() { python3 -c 'import secrets; print(secrets.token_urlsafe(24))'; }
cat > "${ENVF}" <<EOF
DB_NAME=sanfelipe
DB_USER=sanfelipe
DB_PASSWORD=$(clave)
MYSQL_ROOT_PASSWORD=$(clave)
JWT_SECRETO=$(clave)$(clave)
PUERTO_MYSQL=${PUERTO_MYSQL:-33307}
EOF
export ENV_FILE="${ENVF}" COMPOSE_PROJECT_NAME="${PROYECTO}"
dc() { docker compose --env-file "${ENVF}" -p "${PROYECTO}" "$@"; }
limpiar() { dc down -v >/dev/null 2>&1 || true; rm -f "${ENVF}" "${respaldo:-}"; }
trap limpiar EXIT
sql() { dc exec -T basedatos sh -c 'mysql -N -B -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" 2>/dev/null'; }
huellas() {
  local tablas t
  tablas="$(echo "SHOW TABLES" | sql)"
  for t in ${tablas}; do
    printf '%s\t%s\t%s\n' "${t}" "$(echo "SELECT COUNT(*) FROM \`${t}\`" | sql)" \
      "$(echo "CHECKSUM TABLE \`${t}\`" | sql | cut -f2)"
  done
}
ms() { date +%s%3N; }

echo "1. Base nueva con esquema y datos de ejemplo"
dc down -v >/dev/null 2>&1 || true
dc up -d --wait basedatos >/dev/null
if [[ "${FILAS_BITACORA:-0}" -gt 0 ]]; then
  echo "   + ${FILAS_BITACORA} filas sintéticas de bitácora"
  cat <<SQL | sql
SET SESSION cte_max_recursion_depth = ${FILAS_BITACORA};
INSERT INTO bitacora (accion, entidad, entidad_id, detalle)
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < ${FILAS_BITACORA})
SELECT 'p18b_sintetico', 'prueba', i, JSON_OBJECT('fila', i, 'nota', 'dato sintético de volumen') FROM n;
SQL
fi
echo "2. Fila marcadora"
echo "INSERT INTO ruta (codigo, origen, destino, duracion_min, ida_min) VALUES ('R-P18', 'Soritor', 'Prueba P-18b', 100, 40)" | sql
antes="$(huellas)"
echo "3. Respaldo"
t0=$(ms); respaldo="$(herramientas/respaldo.sh | sed -n 's/^Respaldo creado: \([^ ]*\).*/\1/p')"; t_resp=$(( $(ms) - t0 ))
tam="$(du -h "${respaldo}" | cut -f1)"
echo "4. Pérdida simulada: contenedor y volumen eliminados"
dc down -v >/dev/null
echo "5. Restauración"
t0=$(ms)
dc up -d --wait basedatos >/dev/null
t_base=$(( $(ms) - t0 ))
herramientas/respaldo.sh restaurar "${respaldo}" >/dev/null
despues="$(huellas)"
t_total=$(( $(ms) - t0 ))
marcador="$(echo "SELECT COUNT(*) FROM ruta WHERE codigo = 'R-P18'" | sql)"
version="$(echo "SELECT VERSION()" | sql)"
if [[ "${antes}" == "${despues}" && "${marcador}" == "1" ]]; then iguales="sí"; else iguales="no"; fi
if [[ "${iguales}" == "sí" && ${t_total} -le 7200000 ]]; then resultado="Aprobado"; else resultado="Fallido"; fi
seg() { printf '%d.%03d s' $(( $1 / 1000 )) $(( $1 % 1000 )); }

mkdir -p "$(dirname "${salida}")"
{
  echo "# P-18b — restauración del respaldo (${fecha})"
  echo
  echo "Generado por \`herramientas/medir_restauracion.sh\` (RNF-05: restauración completa en ≤ 2 h)."
  echo
  echo "| Dato | Valor |"
  echo "|---|---|"
  echo "| MySQL | ${version} (imagen \`mysql:8.4.11\` de docker-compose.yml) |"
  echo "| Equipo | $(nproc) CPU lógicas; $(. /etc/os-release && echo "${PRETTY_NAME}") |"
  echo "| Datos | \`basedatos/datos_ejemplo.sql\` (ficticios) + 1 fila marcadora + ${FILAS_BITACORA:-0} filas sintéticas de bitácora |"
  echo "| Tamaño del respaldo (gzip) | ${tam} |"
  echo "| Tiempo del respaldo | $(seg ${t_resp}) |"
  echo "| Tiempo hasta tener una base nueva en servicio | $(seg ${t_base}) |"
  echo "| **Tiempo total de restauración** (base nueva + restauración + verificación) | **$(seg ${t_total})** |"
  echo "| Tablas, filas y CHECKSUM TABLE iguales antes y después; fila marcadora presente | ${iguales} |"
  echo "| Resultado (≤ 2 h y datos iguales) | **${resultado}** |"
  echo
  echo "Tablas (nombre, filas, CHECKSUM TABLE) después de restaurar:"
  echo
  echo '```text'
  echo "${despues}"
  echo '```'
  echo
  echo "Limitación: el volumen es el de los datos de ejemplo; con datos reales debe repetirse en el"
  echo "servidor local de la empresa y con el respaldo del día (RNF-05)."
} > "${salida}"
cat "${salida}"
[[ "${resultado}" == "Aprobado" ]]
