#!/usr/bin/env bash
# Ejecuta las pruebas del código del artículo con un entorno determinista y guarda las evidencias.
#   bash pruebas/ejecutar_pruebas.sh                  # entorno, pruebas y reproducción de corridas publicadas
#   SIN_REPRODUCCION=1 bash pruebas/ejecutar_pruebas.sh   # solo entorno y pruebas
#   PYTHON=/ruta/al/python bash pruebas/ejecutar_pruebas.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONHASHSEED=0 PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1
unset PYTHONPATH PYTHONSTARTUP PYTHONHOME
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export TZ=UTC LC_ALL=C.UTF-8 LANG=C.UTF-8 MPLBACKEND=Agg
PY="${PYTHON:-python3}"
SALIDA="${SALIDA_PRUEBAS:-$RAIZ/pruebas/salidas}"
export SALIDA_PRUEBAS="$SALIDA"
mkdir -p "$SALIDA"
cd "$RAIZ"

"$PY" pruebas/entorno.py "$SALIDA/entorno.json" > /dev/null
"$PY" -m pytest pruebas -p no:cacheprovider -v -rxX --junitxml="$SALIDA/junit.xml" 2>&1 | tee "$SALIDA/pytest.log"
if [ -z "${SIN_REPRODUCCION:-}" ]; then
  "$PY" pruebas/reproduccion.py "$SALIDA" 2>&1 | tee "$SALIDA/reproduccion.log"
fi
echo "Evidencias en $SALIDA"
