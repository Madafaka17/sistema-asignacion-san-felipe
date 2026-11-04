#!/usr/bin/env bash
# Ejecuta las pruebas del núcleo con el entorno determinista del proyecto y guarda las evidencias.
#   bash pruebas/nucleo/ejecutar_pruebas.sh            # pruebas + entorno + corridas estocásticas
#   SIN_ESTOCASTICAS=1 bash pruebas/nucleo/ejecutar_pruebas.sh   # solo pruebas y entorno
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$RAIZ/scripts/entorno_determinista.sh"
PY="${PYTHON:-$RAIZ/.venv/bin/python}"
SALIDA="${SALIDA_PRUEBAS:-$RAIZ/pruebas/nucleo/salidas}"
export SALIDA_PRUEBAS="$SALIDA"
mkdir -p "$SALIDA"
cd "$RAIZ"

"$PY" pruebas/nucleo/entorno.py "$SALIDA/entorno.json" > /dev/null
"$PY" -m pytest pruebas/nucleo tests/test_core.py -p no:cacheprovider -v --junitxml="$SALIDA/junit.xml" \
      2>&1 | tee "$SALIDA/pytest.log"
if [ -z "${SIN_ESTOCASTICAS:-}" ]; then
  "$PY" pruebas/nucleo/estocasticas.py "$SALIDA" 2>&1 | tee "$SALIDA/estocasticas.log"
fi
echo "Evidencias en $SALIDA"
