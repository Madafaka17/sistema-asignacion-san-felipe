#!/usr/bin/env bash
# =====================================================================
# Caso real (tesis, sección 5.6.2; EP3, criterio 15): recorre el prototipo
# con la salida del manifiesto 001-029483 de la empresa sobre una base
# vacía y guarda las capturas y el registro con fecha y hora.
#
#   herramientas/caso_real.sh [carpeta_salida]
#
# Levanta MySQL 8.4.11 (imagen de docker-compose.yml) en 127.0.0.1:33310
# solo con el esquema y las tres cuentas del sistema —sin los datos de
# demostración—, arranca el servidor con Dart en el puerto 8090, ejecuta
# cliente/integration_test/caso_real/caso_real_test.dart (Flutter, escritorio
# Linux, con xvfb-run si no hay pantalla) y extrae de la base la entrada, la
# salida y la bitácora. Contraseñas aleatorias que no se guardan.
# Requiere: docker, dart 3.13.5, flutter 3.47.6, xvfb-run e ImageMagick.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
RAIZ="$PWD"
SALIDA="$(mkdir -p "${1:-docs/evidencias/caso_real_001-029483}" && cd "${1:-docs/evidencias/caso_real_001-029483}" && pwd)"
TMP="$(mktemp -d)"
CONTENEDOR=sfreal-mysql
clave() { python3 -c 'import secrets; print(secrets.token_urlsafe(24))'; }
DB_PASSWORD="$(clave)"; RAIZ_PW="$(clave)"; JWT="$(clave)$(clave)"
limpiar() {
  [[ -n "${PID_SERVIDOR:-}" ]] && kill "${PID_SERVIDOR}" 2>/dev/null || true
  docker rm -f "${CONTENEDOR}" >/dev/null 2>&1 || true
  rm -rf "${TMP}"
}
trap limpiar EXIT

echo "1. Base vacía: esquema y cuentas del sistema"
mkdir -p "${TMP}/initdb"
cp basedatos/esquema.sql "${TMP}/initdb/01_esquema.sql"
{ echo "SET NAMES utf8mb4;"; sed -n '/^INSERT INTO usuario/,/;$/p' basedatos/datos_ejemplo.sql; } > "${TMP}/initdb/02_usuarios.sql"
docker rm -f "${CONTENEDOR}" >/dev/null 2>&1 || true
docker run -d --name "${CONTENEDOR}" -e MYSQL_ROOT_PASSWORD="${RAIZ_PW}" -e MYSQL_DATABASE=sanfelipe \
  -e MYSQL_USER=sanfelipe -e MYSQL_PASSWORD="${DB_PASSWORD}" -p 127.0.0.1:33310:3306 \
  -v "${TMP}/initdb:/docker-entrypoint-initdb.d:ro" mysql:8.4.11 \
  --character-set-server=utf8mb4 --collation-server=utf8mb4_0900_ai_ci --default-time-zone=-05:00 >/dev/null
sql() { docker exec -i "${CONTENEDOR}" sh -c 'mysql --default-character-set=utf8mb4 -uroot -p"$MYSQL_ROOT_PASSWORD" sanfelipe' 2>/dev/null; }
for _ in $(seq 1 90); do
  [[ "$(echo 'SELECT COUNT(*) FROM usuario' | sql | tail -1)" == "3" ]] && break
  sleep 2
done

echo "2. Servidor en el puerto 8090 (registro: servidor.log)"
(cd servidor && dart pub get --enforce-lockfile >/dev/null)
(cd servidor && DB_HOST=127.0.0.1 DB_PORT=33310 DB_NAME=sanfelipe DB_USER=sanfelipe DB_PASSWORD="${DB_PASSWORD}" \
  DB_TLS=true JWT_SECRETO="${JWT}" PUERTO=8090 COOKIE_SEGURA=false PARAMETROS_ARCHIVO="${RAIZ}/config/parametros.yaml" \
  exec dart run bin/servidor.dart) > "${SALIDA}/servidor.log" 2>&1 &
PID_SERVIDOR=$!
for _ in $(seq 1 60); do curl -fsS http://localhost:8090/api/salud >/dev/null 2>&1 && break; sleep 2; done

echo "3. Recorrido de la interfaz (capturas en capturas/)"
rm -rf "${SALIDA}/capturas" && mkdir -p "${SALIDA}/capturas"
PANTALLA=(); [[ -z "${DISPLAY:-}" ]] && PANTALLA=(xvfb-run -a -s "-screen 0 1366x860x24")
date -u +"inicio %Y-%m-%dT%H:%M:%SZ" > "${SALIDA}/ejecucion.txt"
estado=0
(cd cliente && flutter pub get --enforce-lockfile >/dev/null && "${PANTALLA[@]}" flutter test \
  integration_test/caso_real/caso_real_test.dart -d linux --dart-define=CASO_REAL=true \
  --dart-define=API_URL=http://localhost:8090/api --dart-define=CAPTURAS="${SALIDA}/capturas") \
  > "${SALIDA}/prueba_interfaz.log" 2>&1 || estado=$?
{ echo "rc=${estado}"; date -u +"fin %Y-%m-%dT%H:%M:%SZ"; } >> "${SALIDA}/ejecucion.txt"

echo "4. Registro de la base: entrada, salida y bitácora (registro_bd.txt)"
docker exec -i "${CONTENEDOR}" sh -c 'mysql --default-character-set=utf8mb4 -t -uroot -p"$MYSQL_ROOT_PASSWORD" sanfelipe' \
  < herramientas/caso_real_extraer.sql 2>/dev/null > "${SALIDA}/registro_bd.txt"
echo "Resultado: $([[ ${estado} -eq 0 ]] && echo PASA || echo FALLA) · evidencias en ${SALIDA}"
exit "${estado}"
