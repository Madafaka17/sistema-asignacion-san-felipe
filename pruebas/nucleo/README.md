# Pruebas del núcleo de optimización (`pruebas/nucleo`)

Suite de pruebas unitarias, de propiedades y de reproducibilidad que cubre los algoritmos, modelos y reglas que
constituyen la contribución original de la tesis *Sistema de asignación de recursos basado en algoritmo genético
para la programación operativa en la Empresa de Transportes San Felipe*. Prueba el núcleo de referencia en Python
(`core/` y `experimentos/poc_cap3/`) y el generador del experimento sintético. Todas las instancias son sintéticas:
no contienen datos de la empresa ni datos personales.

Estado: la ejecución registrada (24/10/2026) usó `core/` y `experimentos/poc_cap3/` de la copia registrada el 6 de
octubre de 2026 y la carpeta `experimentos/sanfelipe/` entregada por el autor el 24 de octubre, idéntica archivo por
archivo a la registrada.

Integración en este repositorio (4/11/2026): la suite se copió en `pruebas/nucleo/`, junto con el `core/` y el
`experimentos/poc_cap3/` originales (huellas iguales a `registro_protocolo.txt`). Único cambio: `ejecutar_pruebas.sh`
y `medir_cobertura.sh` corren `tests/test_core.py` en lugar de `tests/`, porque esa carpeta también contiene el
esqueleto inicial del sistema, con otras dependencias.
Ejecutada aquí (contenedor con Intel Xeon a 2.10 GHz, 4 CPU lógicas, Ubuntu 24.04.5, CPython 3.11.18 y las
dependencias de `requirements.lock`): **109 pruebas aprobadas en 46.43 s** y **300 de 300 corridas estocásticas con
la aptitud registrada** en v1, sin discrepancias del validador. Las evidencias están en `verificacion_2026-11-04/`;
las de `salidas/` son las de la ejecución registrada del 24/10/2026.

## Qué cubre (100 casos en 12 módulos)

| Módulo | Archivo | Componente de la tesis | Casos | Técnicas |
|---|---|---|---:|---|
| M01 | `test_m01_modelo.py` | Modelo y codificación (ec. 1 a 3 y 15) | 6 | Partición; valor límite; propiedad |
| M02 | `test_m02_conflictos.py` | Pares en conflicto Γ e índice de conducción (ec. 4 a 6) | 14 | Partición; valor límite; oráculo; regresión |
| M03 | `test_m03_conduccion.py` | Límite de conducción y exceso *E* (ec. 6 y 7) | 6 | Valor límite; precalculado; oráculo |
| M04 | `test_m04_aptitud.py` | Pérdida *J* y aptitud *F* (ec. 7 y 8) | 14 | Precalculado; oráculo; enumeración |
| M05 | `test_m05_cota_M.py` | Cota *U* y elección de *M* (sección 3.1.2) | 6 | Valor límite; propiedad; control negativo |
| M06 | `test_m06_reparacion.py` | Reparación (sección 3.4.9) | 10 | Regla de negocio; propiedad; caracterización |
| M07 | `test_m07_operadores_ag.py` | Operadores del AG (secciones 3.4.4 a 3.4.7) | 10 | Propiedad; estadística; doble de prueba |
| M08 | `test_m08_parada.py` | Criterios de parada del AG y de la búsqueda tabú | 8 | Valor límite; partición |
| M09 | `test_m09_reglas_As.py` | Reglas de construcción de *A_s* (ec. 1) | 11 | Regla de negocio; valor límite; estadística |
| M10 | `test_m10_validador.py` | Validador independiente de Φ | 4 | Oráculo cruzado; precalculado |
| M11 | `test_m11_comparadores.py` | Métodos de comparación PLE, voraz y tabú (secciones 3.1.4 a 3.1.6) | 8 | Oráculo; datos registrados |
| M12 | `test_m12_reproducibilidad.py` | Reproducibilidad entre procesos y con el registro v1 | 3 | Procesos independientes; datos registrados |

Además, `ejecutar_pruebas.sh` corre las 9 pruebas previas de `tests/` (109 pruebas en total). Los oráculos de
`utilidades.py` están escritos de nuevo, por fuerza bruta, sin importar el código bajo prueba; `conftest.py` registra
cada caso (identificador, vector de entrada crítico, valor esperado, observado, margen y latencia) en
`salidas/casos.jsonl`.

## Requisitos

- Python 3.11 con el entorno del repositorio creado desde `requirements.lock` (por omisión, `.venv/` en la raíz) y
  pytest 9.1.1 (`requirements-dev.txt`).
- `scripts/entorno_determinista.sh` del repositorio (fija `PYTHONHASHSEED=0`, un hilo por biblioteca numérica,
  `TZ=UTC` y `LC_ALL=C.UTF-8`).
- Solo para la cobertura: coverage.py 7.6.12 instalado fuera del entorno de pruebas
  (`pip install --target /ruta/a/coverage coverage==7.6.12`).

## Ejecución (desde la raíz del repositorio)

```bash
# entorno, pruebas y repetición estocástica (300 ejecuciones del AG y de la búsqueda tabú)
bash pruebas/nucleo/ejecutar_pruebas.sh
# solo entorno y pruebas
SIN_ESTOCASTICAS=1 bash pruebas/nucleo/ejecutar_pruebas.sh
# si el intérprete no está en .venv/
PYTHON=/ruta/al/python bash pruebas/nucleo/ejecutar_pruebas.sh
# cobertura de sentencias y ramas
COBERTURA_LIB=/ruta/a/coverage bash pruebas/nucleo/medir_cobertura.sh
```

## Evidencias (`salidas/`)

| Archivo | Contenido |
|---|---|
| `entorno.json` | Hardware, sistema operativo, intérprete y parámetros de compilación, banderas, punto flotante, bibliotecas, variables de entorno y huellas SHA-256 del código evaluado y de las pruebas |
| `pytest.log`, `junit.xml` | Salida de pytest |
| `casos.jsonl` | Un registro por caso: esperado, observado, margen, tolerancia y latencia |
| `corridas_estocasticas.csv`, `resumen_estocasticas.json` | 300 ejecuciones (15 instancias × 10 semillas × 2 métodos) y su resumen |
| `cobertura.txt`, `cobertura.json` | Cobertura de sentencias y ramas |

Resultado de la ejecución registrada (24/10/2026, máquina virtual con Intel Xeon a 2.10 GHz, 2 CPU lógicas y
7.84 GiB; Ubuntu 24.04.5; CPython 3.11.17): 109 pruebas aprobadas en 43.98 s; cobertura de `core/` de 100 % de
sentencias y 99.04 % de ramas (98.35 % con comparadores, validador y generador); las 300 ejecuciones estocásticas
reprodujeron la aptitud registrada en la ejecución oficial v1 y el validador no tuvo discrepancias.

## Nombre de la carpeta del experimento

`rutas.py` localiza el paquete del experimento como `experimentos/sanfelipe/` (nombre actual) o, en copias
anteriores, `experimentos/sintetico_sanfelipe/`. El registro del protocolo (`registro_protocolo.txt`) conserva el
nombre anterior en sus rutas; `entorno.py` hace la equivalencia al comparar huellas. Una ejecución previa (21/10/2026,
sobre la copia registrada con el nombre anterior) obtuvo los mismos valores observados en los cien casos.

Los scripts de la prueba de humo (`pruebas/humo/generar_semilla.py` e `integridad.py`) se actualizaron el
4/11/2026 con la misma regla (`pruebas/humo/README.md`).

## Anomalías registradas y resueltas

| Id. | Resumen | Resolución |
|---|---|---|
| A-01 | Γ dependía del orden de un conjunto de cadenas (`PYTHONHASHSEED`), en la versión anterior al registro | Tupla ordenada; regresión M02-12 y M12-01 |
| A-02 | La reparación aleatoria (`core/repair.py: repair`) aumentó Φ en 1327 de 4000 cromosomas | Caracterizada (M06-10); el AG de la tesis usa la reparación dirigida (M06-07); proponer la corrección del README (abajo) |
| A-03 | El oráculo de M08-03 contaba la generación que fijó el valor (21 en lugar de 20) | Oráculo corregido |
| A-04 | M06-02 calculaba el margen contra otra tupla | Comparación corregida |
| A-05 | M05-05 podía entrar en un ciclo sin fin | Límite de 200,000 intentos con aserción |
| A-06 | Nueve casos sin latencia registrada | `caso.cronometrar` en todos los casos |
| A-07 | La primera versión de `estocasticas.py` medía el tiempo con un criterio distinto del protocolo | Medición alineada con `experimento.py` |
| A-08 | Las rutas de la suite apuntaban a `experimentos/sintetico_sanfelipe/`; la carpeta entregada se llama `experimentos/sanfelipe/` | `rutas.py` acepta ambos nombres; mismos valores observados |

Ninguna anomalía modificó el núcleo (`core/`).

## Propuesta de corrección del README del repositorio (A-02)

En la sección de pruebas, el README dice que las pruebas cubren *«that repair never increases the number of
violations it is asked to fix»*. La prueba `test_repair_does_not_increase_violations` solo lo comprueba en una
instancia construida de tres servicios. Texto propuesto:

> that, on a crafted three-service instance, repair removes the violations it is asked to fix. The random repair
> (`core/repair.py: repair`) does not guarantee this in general: it re-samples alternatives without checking for
> new conflicts and increased the total violations Φ in 1327 of 4000 random chromosomes (case M06-10 of
> `pruebas/nucleo`). The thesis configuration therefore uses the deterministic `repair_targeted`.
