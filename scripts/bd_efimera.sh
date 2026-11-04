#!/usr/bin/env bash
# Servidor MySQL efímero para la prueba de humo, separado de cualquier base de desarrollo:
# directorio de datos nuevo en .build/mysql, solo en 127.0.0.1, puerto de .env (33306 por
# omisión), sin archivos de opciones del sistema (--no-defaults), con un usuario de pruebas
# que solo puede operar sobre las bases sf_test_%. Al detenerlo se borra todo.
#   bash scripts/bd_efimera.sh iniciar | detener | estado
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"
BASE="$RAIZ/.build/mysql"

registro() { printf '%s INFO    [bd_efimera] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
falla() { printf '%s FATAL   [bd_efimera] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; exit 1; }

crear_env() {
  [ -f .env.example ] || falla "falta .env.example"
  clave="$(python3.11 -c 'import secrets; print(secrets.token_urlsafe(24))')"
  sed "s/^SF_BD_CLAVE=.*/SF_BD_CLAVE=${clave}/" .env.example > .env
  chmod 600 .env
  registro ".env creado con una contraseña aleatoria local (no se versiona ni se muestra)"
}

cargar_env() {
  # Lectura sin ejecutar el archivo: solo líneas SF_*=valor.
  while IFS='=' read -r clave valor; do
    [[ "${clave}" =~ ^SF_[A-Z_]+$ ]] || continue
    valor="${valor%\"}"; valor="${valor#\"}"
    export "${clave}=${valor}"
  done < .env
  [[ "${SF_ENTORNO:-}" == "pruebas" ]] || falla "SF_ENTORNO debe ser 'pruebas'"
  [[ "${SF_BD_HOST:-}" == "127.0.0.1" ]] || falla "SF_BD_HOST debe ser 127.0.0.1 para el servidor efímero"
  [[ "${SF_BD_PUERTO:-}" =~ ^[0-9]+$ ]] || falla "SF_BD_PUERTO no es un número"
  [[ "${SF_BD_USUARIO:-}" =~ ^[A-Za-z0-9_]{1,32}$ ]] || falla "SF_BD_USUARIO inválido"
  [[ "${SF_BD_CLAVE:-}" =~ ^[A-Za-z0-9_-]{16,}$ ]] || falla "SF_BD_CLAVE ausente o débil (mínimo 16 caracteres [A-Za-z0-9_-])"
  [[ "${SF_BD_CLAVE}" != "se_genera_al_iniciar_la_bd" ]] || falla "SF_BD_CLAVE conserva el valor de ejemplo; borre .env para generarla"
}

activo() { [ -f "$BASE/mysqld.pid" ] && kill -0 "$(cat "$BASE/mysqld.pid")" 2>/dev/null; }

detener() {
  # Detiene todo mysqld que use el directorio de datos efímero (también uno que haya fallado
  # al arrancar) y borra el directorio de datos y el del socket.
  pids="$(pgrep -f -- "--datadir=$BASE/datos" || true)"
  if [ -f "$BASE/mysqld.pid" ]; then pids="${pids} $(cat "$BASE/mysqld.pid")"; fi
  for pid in ${pids}; do kill "${pid}" 2>/dev/null || true; done
  for pid in ${pids}; do
    for _ in $(seq 1 60); do kill -0 "${pid}" 2>/dev/null || break; sleep 1; done
    if kill -0 "${pid}" 2>/dev/null; then falla "mysqld (${pid}) no se detuvo"; fi
  done
  if [ -n "${pids// /}" ]; then
    registro "servidor detenido (pid $(echo ${pids} | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//'))"
  fi
  if ls "$BASE"/*.err >/dev/null 2>&1; then          # conservar los registros del servidor
    destino="$RAIZ/.build/registros_mysql/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "${destino}" && cp "$BASE"/*.err "${destino}/"
  fi
  if [ -f "$BASE/socket_dir" ]; then rm -rf "$(cat "$BASE/socket_dir")"; fi
  for _ in 1 2 3 4 5; do rm -rf "$BASE" 2>/dev/null && break; sleep 1; done
  [ ! -e "$BASE" ] || falla "no se pudo borrar $BASE"
  registro "directorio de datos efímero eliminado"
}

iniciar() {
  [ -f .env ] || crear_env
  cargar_env
  detener >/dev/null
  mkdir -p "$BASE/datos" "$BASE/tmp"
  chmod 700 "$BASE"
  # El socket Unix va en un directorio temporal de ruta corta: la ruta de un socket no puede
  # superar 107 caracteres y la carpeta del proyecto puede estar muy anidada.
  dir_socket="$(mktemp -d /tmp/sfhumo.XXXXXX)"
  echo "${dir_socket}" > "$BASE/socket_dir"
  SOCKET="${dir_socket}/mysqld.sock"
  opc_usuario=()
  [ "$(id -u)" -eq 0 ] && opc_usuario=(--user=root)
  mysqld --no-defaults --initialize-insecure --datadir="$BASE/datos" "${opc_usuario[@]}" \
    --log-error="$BASE/inicializacion.err" || falla "no se pudo inicializar el directorio de datos"
  mysqld --no-defaults --daemonize --datadir="$BASE/datos" --socket="${SOCKET}" \
    --pid-file="$BASE/mysqld.pid" --port="${SF_BD_PUERTO}" --bind-address=127.0.0.1 --skip-name-resolve \
    --mysqlx=OFF --skip-log-bin --tmpdir="$BASE/tmp" --log-error="$BASE/mysqld.err" \
    --performance-schema=OFF --innodb-buffer-pool-size=64M --secure-file-priv=NULL \
    "${opc_usuario[@]}" >/dev/null \
    || falla "mysqld no arrancó (al terminar, su registro se copia en .build/registros_mysql/)"
  for _ in $(seq 1 60); do
    mysqladmin --no-defaults --socket="${SOCKET}" -uroot ping >/dev/null 2>&1 && break
    sleep 1
  done
  mysqladmin --no-defaults --socket="${SOCKET}" -uroot ping >/dev/null 2>&1 || falla "mysqld no responde"
  sql="$(cat <<'SQL'
CREATE USER '__USUARIO__'@'127.0.0.1' IDENTIFIED BY '__CLAVE__';
GRANT ALL PRIVILEGES ON `sf\_test\_%`.* TO '__USUARIO__'@'127.0.0.1';
ALTER USER 'root'@'localhost' ACCOUNT LOCK;
SQL
)"
  sql="${sql//__USUARIO__/${SF_BD_USUARIO}}"
  sql="${sql//__CLAVE__/${SF_BD_CLAVE}}"
  printf '%s\n' "${sql}" | mysql --no-defaults --socket="${SOCKET}" -uroot \
    || falla "no se pudo crear el usuario de pruebas"
  version="$(mysqld --version | sed -E 's/.*Ver ([^ ]+).*/\1/')"
  registro "MySQL ${version} efímero en 127.0.0.1:${SF_BD_PUERTO} (pid $(cat "$BASE/mysqld.pid")); usuario ${SF_BD_USUARIO} limitado a sf_test_%; root bloqueado"
}

case "${1:-}" in
  iniciar) iniciar ;;
  detener) detener ;;
  estado) if activo; then echo "activo (pid $(cat "$BASE/mysqld.pid"))"; else echo "detenido"; fi ;;
  *) echo "uso: $0 iniciar|detener|estado" >&2; exit 2 ;;
esac
