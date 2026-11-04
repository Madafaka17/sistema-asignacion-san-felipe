#!/usr/bin/env bash
# Construcción determinista y prueba de humo, de principio a fin, usando solo los scripts
# del proyecto. Código de salida: 0 si todo pasa; distinto de 0 ante el primer fallo.
#   bash scripts/construir_y_probar.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"
source scripts/entorno_determinista.sh

bash scripts/aprovisionar.sh                       # A1 a A5
trap 'bash scripts/bd_efimera.sh detener' EXIT     # el servidor se detiene y se borra pase lo que pase
bash scripts/bd_efimera.sh iniciar                 # servidor de pruebas efímero

.venv/bin/python -s -m pytest -q -p no:cacheprovider tests/test_core.py     # pruebas unitarias del núcleo
.venv/bin/python -s -m pruebas.humo.prueba_humo                 # prueba de humo: PASA o FALLA
