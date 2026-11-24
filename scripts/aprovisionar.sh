#!/usr/bin/env bash
# Aprovisionamiento determinista del entorno de pruebas (Ubuntu 24.04 LTS, amd64).
#   A1  Integridad del paquete (SHA256SUMS)
#   A2  Paquetes del sistema con versión exacta y huella del .deb (sistema.lock)
#   A3  Entorno virtual nuevo con Python 3.11.15
#   A4  Dependencias de Python con versión exacta y huella (requirements.lock)
#   A5  Compilación determinista a bytecode y registro de la construcción
# Termina con código distinto de 0 ante cualquier diferencia (bloqueo estricto).
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"
source scripts/entorno_determinista.sh

registro() { printf '%s INFO    [aprovisionar] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
falla() { printf '%s FATAL   [aprovisionar] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; exit 1; }
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# A1 -------------------------------------------------------------------------------------------
[ -f SHA256SUMS ] || falla "falta SHA256SUMS en la raíz del paquete"
sha256sum --quiet --strict -c SHA256SUMS || falla "A1: hay archivos alterados respecto de SHA256SUMS"
registro "A1 integridad del paquete: $(grep -c . SHA256SUMS) archivos verificados"

# A2 -------------------------------------------------------------------------------------------
# Se descargan y verifican primero todos los .deb que falten; luego se instalan en una sola
# transacción de apt, de modo que cada paquete fijado proviene del archivo verificado.
tmp_deb="$(mktemp -d)"
pendientes=()
while read -r paquete version huella; do
  [[ -z "${paquete}" || "${paquete}" == \#* ]] && continue
  instalada="$(dpkg-query -W -f='${Version}' "${paquete}" 2>/dev/null || true)"
  if [ "${instalada}" = "${version}" ]; then
    registro "A2 ${paquete} ${version}: ya instalado"
    continue
  fi
  [ "${huella}" != "-" ] || falla "A2: ${paquete} ${version} debe instalarse antes (instalado: '${instalada:-ninguno}')"
  # SF_DEBS (opcional, 2026-11-04): carpeta con .deb ya descargados, p. ej. versiones que el
  # archivo de Ubuntu reemplazó y que siguen en snapshot.ubuntu.com (MANUAL_COMPILACION.md).
  # Su huella se verifica igual que la de los descargados con apt.
  local_deb="${SF_DEBS:-}/${paquete}_${version}_amd64.deb"
  if [ -n "${SF_DEBS:-}" ] && [ -f "${local_deb}" ]; then
    cp "${local_deb}" "${tmp_deb}/"
  elif ! (cd "${tmp_deb}" && apt-get download "${paquete}=${version}" >/dev/null 2>&1); then
    ${SUDO} apt-get update >/dev/null
    (cd "${tmp_deb}" && apt-get download "${paquete}=${version}" >/dev/null 2>&1) \
      || falla "A2: no se pudo descargar ${paquete}=${version}"
  fi
  deb="$(ls "${tmp_deb}/${paquete}_"*.deb)"
  echo "${huella}  ${deb}" | sha256sum --quiet --strict -c - || falla "A2: huella distinta en ${deb##*/}"
  pendientes+=("${deb}")
  registro "A2 ${paquete} ${version}: descargado, huella del .deb verificada"
done < sistema.lock
if [ "${#pendientes[@]}" -gt 0 ]; then
  DEBIAN_FRONTEND=noninteractive ${SUDO} apt-get install -y --no-install-recommends "${pendientes[@]}" >/dev/null \
    || falla "A2: no se pudieron instalar los paquetes verificados"
  registro "A2 instalados ${#pendientes[@]} paquetes desde los .deb verificados (una transacción)"
fi
rm -rf "${tmp_deb}"
while read -r paquete version _; do
  [[ -z "${paquete}" || "${paquete}" == \#* ]] && continue
  [ "$(dpkg-query -W -f='${Version}' "${paquete}" 2>/dev/null || true)" = "${version}" ] \
    || falla "A2: ${paquete} no quedó en la versión ${version}"
done < sistema.lock
registro "A2 paquetes del sistema en las versiones fijadas: $(grep -cvE '^(#|$)' sistema.lock)"

# A3 -------------------------------------------------------------------------------------------
rm -rf .venv .build/pycache
python3.11 -m venv .venv
v="$(.venv/bin/python -c 'import platform; print(platform.python_version())')"
[ "${v}" = "3.11.15" ] || falla "A3: Python ${v} en .venv; se requiere 3.11.15"
registro "A3 entorno virtual nuevo: Python ${v}, pip $(.venv/bin/python -m pip --version | cut -d' ' -f2)"

# A4 -------------------------------------------------------------------------------------------
.venv/bin/python -s -m pip install --quiet --no-deps --require-hashes --only-binary=:all: --no-compile \
  -r requirements.lock || falla "A4: la instalación desde requirements.lock falló"
.venv/bin/python -s -m pip check >/dev/null || falla "A4: dependencias incompatibles (pip check)"
registro "A4 dependencias instaladas con huella verificada: $(grep -cE '^[a-z0-9]' requirements.lock) paquetes"

# A5 -------------------------------------------------------------------------------------------
salida="$(.venv/bin/python -s scripts/compilar.py)" || falla "A5: la compilación falló"
registro "A5 ${salida}"
registro "aprovisionamiento terminado"
