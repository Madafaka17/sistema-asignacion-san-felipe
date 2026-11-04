#!/usr/bin/env bash
# Mide la cobertura de sentencias y ramas del núcleo con la suite pruebas/nucleo + tests (RNF-07: umbral 80 %).
#   COBERTURA_LIB=/ruta/a/coverage bash pruebas/nucleo/medir_cobertura.sh
# coverage.py no forma parte de requirements.lock: se instala aparte (pip install --target DIR coverage==7.6.12)
# para no alterar el entorno con el que se obtuvieron los resultados de las pruebas.
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$RAIZ/scripts/entorno_determinista.sh"
PY="${PYTHON:-$RAIZ/.venv/bin/python}"
SALIDA="${SALIDA_PRUEBAS:-$RAIZ/pruebas/nucleo/salidas}"
export PYTHONPATH="${COBERTURA_LIB:?indique la carpeta donde se instaló coverage}"
export COVERAGE_FILE="$RAIZ/.build/cobertura.dat"
export SALIDA_PRUEBAS="$RAIZ/.build/salidas_cobertura"      # el registro de casos de esta medición no reemplaza al oficial
mkdir -p "$SALIDA" "$SALIDA_PRUEBAS"
cd "$RAIZ"
SANF=experimentos/sanfelipe                                   # nombre actual; en copias anteriores, sintetico_sanfelipe
[ -d "$SANF" ] || SANF=experimentos/sintetico_sanfelipe
INCLUIR="core/*,experimentos/poc_cap3/*,$SANF/generador_sanfelipe.py"
"$PY" -m coverage run --branch --include="$INCLUIR" -m pytest pruebas/nucleo tests/test_core.py -p no:cacheprovider -q
"$PY" -m coverage report -m --include="$INCLUIR" | tee "$SALIDA/cobertura.txt"
"$PY" -m coverage json --include="$INCLUIR" -o "$SALIDA/cobertura.json" > /dev/null
echo "Cobertura en $SALIDA/cobertura.txt y cobertura.json"
