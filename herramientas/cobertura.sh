#!/usr/bin/env bash
# =====================================================================
# Cobertura de líneas del paquete dominio (RNF-07: núcleo ≥ 80 %).
#
#   herramientas/cobertura.sh            # informe por carpeta y umbral
#   UMBRAL=85 herramientas/cobertura.sh
#
# Deja el informe LCOV en paquetes/dominio/coverage/lcov.info (ignorado por
# git) y termina con error si el núcleo (lib/src/optimizacion) no alcanza el
# umbral.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/../paquetes/dominio"
UMBRAL="${UMBRAL:-80}"

dart pub global activate coverage 1.15.0 > /dev/null
export PATH="$PATH:$HOME/.pub-cache/bin"
rm -rf coverage
dart test --coverage=coverage
format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib --package=.

awk -v umbral="$UMBRAL" '
  /^SF:/ { n = split($0, p, "/lib/src/"); split(p[n], q, "/"); carpeta = q[1] }
  /^DA:/ { split(substr($0, 4), d, ","); total[carpeta]++; if (d[2] > 0) cubiertas[carpeta]++ }
  END {
    for (c in total) {
      pct = 100 * cubiertas[c] / total[c]
      printf "%-14s %4d / %4d líneas = %5.1f %%\n", c, cubiertas[c], total[c], pct
      todas += total[c]; todasCub += cubiertas[c]
    }
    printf "%-14s %4d / %4d líneas = %5.1f %%\n", "TOTAL", todasCub, todas, 100 * todasCub / todas
    nucleo = 100 * cubiertas["optimizacion"] / total["optimizacion"]
    if (nucleo < umbral) { printf "El núcleo (optimizacion) tiene %.1f %% < %s %%\n", nucleo, umbral; exit 1 }
    printf "Núcleo (optimizacion): %.1f %% ≥ %s %% (RNF-07)\n", nucleo, umbral
  }' coverage/lcov.info
