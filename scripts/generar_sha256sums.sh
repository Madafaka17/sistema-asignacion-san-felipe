#!/usr/bin/env bash
# Regenera SHA256SUMS con la huella de cada archivo versionado del núcleo de referencia
# (excluye el entorno local: .env, .venv, .build y las evidencias de pruebas/humo/salidas).
#
# Adaptación del 2026-11-04: en el paquete original (sesión 8) SHA256SUMS cubría todo el
# repositorio del núcleo. Integrado en el repositorio del sistema, cubre solo los archivos
# del núcleo y de sus pruebas (lista RUTAS), no el prototipo Dart/Flutter, para que un
# cambio del prototipo no bloquee la prueba de humo (paso A1 de aprovisionar.sh).
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"
RUTAS=(core experimentos persistencia pruebas/__init__.py pruebas/humo pruebas/nucleo pruebas/corrida bd
       config/humo.json scripts examples tests/test_core.py requirements.in requirements.lock
       requirements-dev.txt sistema.lock .env.example docs/MANUAL_COMPILACION.md docs/INFORME_PRUEBA_HUMO.md
       docs/diagramas/generar_diagramas.py docs/diagramas/common.iuml docs/diagramas/componentes.puml
       docs/diagramas/componentes.png docs/diagramas/componentes.svg docs/diagramas/despliegue.puml
       docs/diagramas/despliegue.png docs/diagramas/despliegue.svg)
find "${RUTAS[@]}" -type f \
  -not -path 'pruebas/humo/salidas/*' -not -path '*/__pycache__/*' -not -name '*.pyc' \
  -not -name '.env' -not -name 'SHA256SUMS' -print0 \
  | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS
echo "SHA256SUMS: $(wc -l < SHA256SUMS) archivos"
