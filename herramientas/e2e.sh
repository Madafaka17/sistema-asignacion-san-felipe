#!/usr/bin/env bash
# =====================================================================
# Pruebas de integración del cliente (escritorio Linux) contra el
# servidor y la base de demostración en marcha.
#
#   herramientas/e2e.sh                      # usa los valores del .env
#   CAPTURAS=docs/capturas herramientas/e2e.sh
#
# Requiere: Flutter 3.47.6, dependencias de escritorio de Linux y, sin
# pantalla, xvfb-run. Antes: `docker compose up -d` (o el servidor local).
# Cada archivo se ejecuta por separado: Flutter no puede lanzar dos veces
# la aplicación de escritorio en la misma invocación.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

API_URL="${E2E_API_URL:-http://localhost:${PUERTO_SERVIDOR:-8080}/api}"
DEFINES=(
  "--dart-define=API_URL=${API_URL}"
  "--dart-define=E2E_DB_HOST=${E2E_DB_HOST:-127.0.0.1}"
  "--dart-define=E2E_DB_PORT=${E2E_DB_PORT:-${PUERTO_MYSQL:-3306}}"
  "--dart-define=E2E_DB_NAME=${E2E_DB_NAME:-${DB_NAME:-sanfelipe}}"
  "--dart-define=E2E_DB_USER=${E2E_DB_USER:-${DB_USER:-sanfelipe}}"
  "--dart-define=E2E_DB_PASSWORD=${E2E_DB_PASSWORD:-${DB_PASSWORD:?Defina DB_PASSWORD en .env}}"
)
if [[ -n "${CAPTURAS:-}" ]]; then
  mkdir -p "${CAPTURAS}"
  DEFINES+=("--dart-define=CAPTURAS=$(cd "${CAPTURAS}" && pwd)")
fi

PANTALLA=()
if [[ -z "${DISPLAY:-}" ]]; then
  PANTALLA=(xvfb-run -a -s "-screen 0 1366x860x24")
fi

curl -fsS "${API_URL}/salud" > /dev/null || { echo "El servidor no responde en ${API_URL}"; exit 1; }

cd cliente
for prueba in integration_test/*_test.dart; do
  echo "==> ${prueba}"
  "${PANTALLA[@]}" flutter test "${prueba}" -d linux "${DEFINES[@]}"
done
