#!/usr/bin/env bash
# Mide la cobertura de sentencias y ramas del código del artículo con la suite pruebas/.
#   COBERTURA_LIB=/ruta/a/coverage bash pruebas/medir_cobertura.sh
# coverage.py se instala aparte (pip install --target DIR coverage==7.6.12) para no alterar el entorno de las pruebas.
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONHASHSEED=0 PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1 OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1 TZ=UTC LC_ALL=C.UTF-8 LANG=C.UTF-8 MPLBACKEND=Agg
PY="${PYTHON:-python3}"
SALIDA="${SALIDA_PRUEBAS:-$RAIZ/pruebas/salidas}"
export PYTHONPATH="${COBERTURA_LIB:?indique la carpeta donde se instaló coverage}"
TMPD="$(mktemp -d)"
export COVERAGE_FILE="$TMPD/cobertura.dat"
export SALIDA_PRUEBAS="$TMPD/salidas"            # el registro de casos de esta medición no reemplaza al oficial
mkdir -p "$SALIDA" "$SALIDA_PRUEBAS"
cd "$RAIZ"
INCLUIR="modelo.py,reparacion.py,genetico.py,metodos.py,validador.py,generador_sintetico.py,generador_gtfs.py,experimento.py,analisis.py"
"$PY" -m coverage run --branch --include="$INCLUIR" -m pytest pruebas -p no:cacheprovider -q
"$PY" -m coverage report -m --include="$INCLUIR" | tee "$SALIDA/cobertura.txt"
"$PY" -m coverage json --include="$INCLUIR" -o "$SALIDA/cobertura.json" > /dev/null
echo "Cobertura en $SALIDA/cobertura.txt y cobertura.json"
