# Revisión del EP3: lo que pide la tesis, lo que hay en el repositorio y lo que falta

Revisión del 4/11/2026 de la tesis v6 (EP3), del paquete del EP3 y de los paquetes de las
sesiones 8 a 10 frente a este repositorio (rama `claude/lucid-feynman-ybqrwy`). Todas las
cifras de este documento se obtuvieron ejecutando el código del repositorio ese día.

## 1. Estado del repositorio frente a lo que la tesis describe

| Lo que describe la tesis | Dónde está ahora | Verificación del 4/11/2026 |
|---|---|---|
| Núcleo de referencia en Python (`core/`) y candidatos (`experimentos/poc_cap3/`), Anexo E | `core/`, `experimentos/poc_cap3/` — **archivos originales**, recuperados del paquete de la sesión 8 | 14 de 14 huellas iguales a `registro_protocolo.txt` (CI «Experimento Python») |
| Experimento registrado (Anexo E, Tablas E1 y E2) | `experimentos/sanfelipe/` | 1 320 de 1 320 soluciones y 12 de 12 óptimos de n = 7 reevaluados; `datos/` se regenera idéntico |
| Corrida paso a paso (sección 4.4, Tablas 44 a 49, Figura 8) | `pruebas/corrida/` | traza idéntica a la registrada (salvo tiempo y versión de Python) |
| 100 casos unitarios del núcleo (sección 5.6.5, Anexo I) y 9 previos | `pruebas/nucleo/`, `tests/test_core.py` | **109 aprobadas** en 46.43 s (CPython 3.11.18) |
| Variabilidad estocástica y reproducción v1 (Tablas 90 y 93) | `pruebas/nucleo/estocasticas.py` | **300 de 300** corridas con la aptitud registrada; validador sin discrepancias |
| Prueba de humo con MySQL (sección 5.6.8, Tabla 92) | `pruebas/humo/`, `persistencia/`, `bd/`, `scripts/`, `config/humo.json` | **PASA 12 de 12**, huella de salida `d61c2499…5cbf` igual a la de referencia (otro equipo; ver §3) |
| Manual de compilación y versiones fijadas (Tabla 84, RNF-08) | `docs/MANUAL_COMPILACION.md`, `requirements.lock` (13 paquetes, 251 huellas), `sistema.lock` | A1 verificado; A2 instaló MySQL 8.0.46 desde `.deb` con huella verificada |
| Esquema mínimo del núcleo (Tabla 79, Figura 41) | `bd/esquema.sql` (9 tablas) | P05 de la prueba de humo |
| Diagramas de componentes, despliegue, casos de uso, objetos, estados y ER | `docs/diagramas/` | generadores incluidos |
| Modelo económico (capítulo VI) | `economia/` (versión EP3, 3/11/2026: VAN S/ 65.87) | idéntico byte a byte con Python ≥ 3.12 |
| Pruebas del código del artículo (Tabla I3) | `articulo/pruebas/` | son las de `02_codigo` del artículo, no de este repositorio |
| P-17: núcleo Dart, 112 servicios, 10 semillas, ≤ 300 s y cobertura ≥ 80 % (Tabla 87) | `paquetes/dominio/tool/p17.dart`, `herramientas/cobertura.sh`; `docs/evidencias/p17/` | **Aprobado**: media 0.351 s, máximo 0.449 s; 10 de 10 factibles; cobertura del núcleo 97.9 % |
| P-18b: restauración del respaldo ≤ 2 h (Tabla 87, RNF-05) | `herramientas/medir_restauracion.sh`; `docs/evidencias/p18b/` | **Aprobado**: 17.3 s (datos de ejemplo) y 25.3 s (con 500 000 filas de bitácora); tablas, filas y `CHECKSUM TABLE` iguales |
| P-03b, P-04b, P-10b y P-13b (fallidos en la Tabla 87, commit b54c86b) | `servidor/test/aceptacion/cola_pares_test.dart`, `hu07_09_programacion_test.dart` (versiones 1.1.0 y 1.2.0) | cubiertos por pruebas de aceptación: cola por destino, pares autorizados, salto de cola explicado y motivo obligatorio del ajuste |

## 2. Correcciones sugeridas al texto de la tesis

| Lugar | Dice | Sugerencia |
|---|---|---|
| Anexo H | implementación en el commit b54c86b, versión 1.0.0; `main` con el esqueleto inicial; `core/` y `poc_cap3/` ausentes | citar el commit final de la rama o de `main` después de fusionar; versión 1.2.0; enumerar `core/`, `experimentos/`, `pruebas/{nucleo,humo,corrida}`, `persistencia/`, `bd/`, `scripts/`, `economia/` y `docs/MANUAL_COMPILACION.md` |
| Secciones 5.4 a 5.6 y Tabla 84 | «repositorio del núcleo de referencia» como repositorio aparte | el núcleo está integrado en el mismo repositorio del sistema (`docs/MANUAL_COMPILACION.md`, sección 13) |
| Sección 5.3.4 y Tablas 86 y 97 («14 tablas») | el esquema del prototipo tiene 14 tablas | `basedatos/esquema.sql` tiene **17 tablas y 1 vista**: se agregaron `par_autorizado`, `cola`, `entrada_cola` y `snapshot_entrada` (versiones 1.1.0 y 1.2.0) |
| Tablas 82 y 83 | RF-05, RF-08, RF-12, RF-14 y RF-15 «pendiente» o «parcial» | implementados en 1.1.0 (cola por destino, pares autorizados, marca del salto, motivo obligatorio) y 1.2.0 (procedencia y versiones); conviene volver a revisar los estados contra ese código |
| Tabla 87 | P-03b, P-04b, P-10b, P-13b «Fallido»; P-17 y P-18b «No ejecutado» | P-03b a P-13b: aprobados por las pruebas de aceptación citadas en §1; P-17 y P-18b: aprobados con las cifras de §1 (entorno de pruebas, no el mini PC) |
| Tabla de RNF (RNF-07) y sección 5.6.9 | «núcleo Dart no medido (P-17)»; «deberá medirse» | cobertura del núcleo Dart: 97.9 % de líneas (`lib/src/optimizacion`); total del paquete `dominio`: 79.0 % |
| Tabla 87, E2E-01 | «falta su salida» | la CI publica en cada commit el artefacto `evidencia-e2e` con la salida y las capturas |
| Número de pruebas del prototipo (116 o 118 según la sección) | — | `paquetes/dominio` 88, `servidor` 66, `cliente` 17 y 2 de integración (`docs/pruebas.md`) |
| Sección 5.6.8 | una sola plataforma verificada | se puede añadir la verificación del 4/11/2026 en otro equipo (contenedor Ubuntu 24.04.5, 4 CPU Xeon 2.10 GHz): PASA 12 de 12, misma huella de salida, 59.5 MiB de memoria residente máxima |

## 3. Pendientes y advertencias

La autoevaluación frente a la rúbrica del EP3 (32 criterios), con lo completado y lo que solo
puede hacer el autor, está en [`docs/ep3/autoevaluacion_rubrica_EP3.md`](ep3/autoevaluacion_rubrica_EP3.md).

- **Reproducibilidad del entorno de la prueba de humo.** `sistema.lock` fija
  `libprotobuf-lite32t64 3.21.12-8.2ubuntu0.3`, que el archivo de Ubuntu ya reemplazó por
  `…0.4`; sigue en `snapshot.ubuntu.com` con la misma huella (se agregó `SF_DEBS` a
  `aprovisionar.sh`). Python 3.11.15 de deadsnakes no estuvo disponible en el equipo de
  verificación: se usó CPython 3.11.15 de python-build-standalone, por lo que A2 se detuvo y
  A3 a A5 se ejecutaron a mano. Conviene repetir la prueba en el mini PC antes de comprarlo.
- **Etiquetas v1.0.0 a v1.2.0.** Desde esta sesión el envío de etiquetas devuelve HTTP 403;
  deben publicarse desde una cuenta con permiso.
- **Datos reales.** El caso real de la sección 5.6.2 se ejecutó el 4/11/2026 con la salida del
  manifiesto 001-029483 (`docs/evidencias/caso_real_001-029483/`, `herramientas/caso_real.sh`):
  PASA, con 15 capturas, el registro del servidor y la extracción de la base. Lo demás usa datos
  sintéticos o ficticios; la validación con un turno completo de RD-01 sigue pendiente.
- **README original del núcleo (anomalía A-02).** `pruebas/nucleo/README.md` propone
  corregir la frase sobre la reparación aleatoria; el README original se conserva sin cambios
  en `core/README.md` hasta que el autor decida.
- **Código del artículo.** La anomalía B-01 (`metodos.exacto`) y la declaración de la versión
  de Python (B-07) corresponden a `02_codigo`, fuera de este repositorio.
- **Informe técnico-económico.** Quedan las capturas E-01 a E-21, las cotizaciones COT-01 y
  COT-02, la tarifa eléctrica del recibo y la confirmación de los supuestos de dedicación.
