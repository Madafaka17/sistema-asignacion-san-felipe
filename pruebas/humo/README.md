# `pruebas/humo/` — prueba de humo del núcleo con MySQL (tesis, sección 5.6.8, Tabla 92)

Recorre la cadena base de datos → núcleo → base de datos con un turno sintético mínimo
(`bd/semilla_humo.sql`: 7 servicios, 3 unidades, 4 conductores, 6 autorizaciones y 27
alternativas; semilla 9001) en una base efímera `sf_test_humo_<id>` de un servidor
MySQL 8.0.46 efímero, y termina con un resultado binario: **PASA** solo si se superan
los 12 pasos P01 a P12. Se ejecuta con `bash scripts/construir_y_probar.sh`; el
procedimiento completo, los requisitos y los criterios de rechazo están en
[`docs/MANUAL_COMPILACION.md`](../../docs/MANUAL_COMPILACION.md) y el informe de la
ejecución de referencia, en [`docs/INFORME_PRUEBA_HUMO.md`](../../docs/INFORME_PRUEBA_HUMO.md).

| Archivo | Contenido |
|---|---|
| `prueba_humo.py` | los 12 pasos, el bloqueo estricto, la limpieza y el informe |
| `integridad.py` | huellas registradas, instantánea de `core/` y `experimentos/`, semillas reservadas |
| `generar_semilla.py` | genera `bd/semilla_humo.sql` (se ejecutó una vez; la prueba carga el SQL estático) |
| `evidencias/` | ejecuciones registradas (ver abajo) |
| `salidas/` | evidencias de cada ejecución local (no se versionan) |

## Origen y adaptaciones

Los archivos provienen sin cambios del paquete del repositorio del núcleo de la
sesión 8 (`paquete_repositorio.zip`, 7/10/2026), salvo estas adaptaciones del
4/11/2026 para integrarlo en el repositorio del sistema:

| Archivo | Cambio | Motivo |
|---|---|---|
| `integridad.py`, `generar_semilla.py` | la carpeta del experimento se busca como `experimentos/sanfelipe/` y, si no existe, `experimentos/sintetico_sanfelipe/`; las huellas se siguen leyendo del registro con su ruta original | la carpeta se renombró después del registro (anomalía A-08; pendiente señalado en el LEEME de las sesiones 9 y 10) |
| `scripts/construir_y_probar.sh`, `pruebas/nucleo/ejecutar_pruebas.sh`, `pruebas/nucleo/medir_cobertura.sh` | `pytest tests` → `pytest tests/test_core.py` | en este repositorio `tests/` también contiene el esqueleto inicial (`src/`), cuyas pruebas necesitan otras dependencias |
| `scripts/compilar.py` | compila `pruebas/__init__.py` y `pruebas/humo` en lugar de todo `pruebas/` | `pruebas/` también contiene `nucleo/` y `corrida/`; se conserva el alcance del paquete original |
| `scripts/generar_sha256sums.sh` | `SHA256SUMS` cubre solo los archivos del núcleo y de sus pruebas | el repositorio también contiene el prototipo Dart/Flutter |
| `scripts/aprovisionar.sh` | variable opcional `SF_DEBS` con `.deb` ya descargados (su huella se verifica igual) | `libprotobuf-lite32t64 3.21.12-8.2ubuntu0.3` ya no está en el archivo de Ubuntu (lo reemplazó `…0.4`); sigue en `snapshot.ubuntu.com` con la huella de `sistema.lock` |
| `.env.example`, `.gitignore` | variables `SF_*` agregadas a la plantilla del prototipo; `.build/` y `salidas/` excluidos | un solo `.env` para el repositorio |

## Evidencias (`evidencias/`)

| Carpeta | Ejecución | Entorno | Resultado |
|---|---|---|---|
| `2026-10-07/ejecucion_referencia` | 20261007T144734Z (referencia de la Tabla 92) | VM Ubuntu 24.04.4, 2 vCPU Xeon 2.80 GHz, Python 3.11.15 (deadsnakes), MySQL 8.0.46 | PASA |
| `2026-10-07/reproduccion`, `verificacion_independiente`, `verificacion_paquete_final` | repeticiones del 7/10/2026 en otra carpeta y por el manual | ídem | PASA, misma huella de salida |
| `2026-10-07/pruebas_negativas.txt` | fallos controlados N1 a N3 (núcleo alterado, contraseña errónea, dependencia distinta) | ídem | FALLA en P01, P04 y P02, como se esperaba |
| `2026-11-04_contenedor` | 20261104T152514Z_aad1, después de integrar el paquete en este repositorio | contenedor Ubuntu 24.04.5, 4 CPU Xeon 2.10 GHz; MySQL 8.0.46 y bibliotecas de `sistema.lock` instaladas desde `.deb` con su huella verificada; **Python 3.11.15 de python-build-standalone (uv), no el `.deb` de deadsnakes**, que no estaba disponible (por eso A2 de `aprovisionar.sh` se detuvo y A3 a A5 se ejecutaron a mano con las mismas órdenes) | **PASA** (12 de 12) en 1.56 s; huella de salida `d61c2499…5cbf`, **igual a la de referencia**; memoria residente máxima 59.5 MiB |
