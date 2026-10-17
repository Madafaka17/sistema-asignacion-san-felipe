# Evidencia experimental de la determinación del método

Esta carpeta conserva la evidencia del **experimento comparativo** de la
sección 3.2.3 de la tesis (Anexo E): los cuatro candidatos —programación
lineal entera (PLE), algoritmo voraz, búsqueda tabú y algoritmo genético
(AG)— sobre instancias **sintéticas** con la estructura de la operación de
Soritor (colas por destino, conductor habitual y reemplazos autorizados,
viajes redondos a Moyobamba y a Tarapoto).

| Variante | Qué es | AG | PLE | Búsqueda tabú | Voraz |
|---|---|---:|---:|---:|---:|
| v1 | ejecución oficial (Tabla 19) | **4.45** | 4.05 | 2.80 | 2.35 |
| v2 | sensibilidad del presupuesto, prevista en el protocolo (Tabla 20) | **4.85** | 4.05 | 2.65 | 2.50 |
| v1D | exploratoria: D sobre todos los conductores (Anexo F) | 4.45 | **4.50** | 2.80 | 2.50 |
| v2D | exploratoria: D sobre todos los conductores | **4.70** | 4.35 | 2.65 | 2.50 |

Con la ejecución oficial v1 la sección 3.3 determina el **algoritmo genético**
como método del sistema; PLE, voraz y búsqueda tabú quedan como comparadores
experimentales. El validador independiente coincidió con Φ en las 1 320
ejecuciones.

## `sanfelipe/` — paquete del Anexo E, sin modificar

Los archivos de [`sanfelipe/`](sanfelipe/) son los del paquete entregado por el
autor, copiados **sin cambios** para conservar sus huellas; los únicos agregados
son el material suplementario descrito más abajo y nuevas secciones de
`README.md` y `DESVIACIONES.md`, que no tienen huella registrada. Las huellas
SHA-256 de los cinco archivos que definen el experimento coinciden con las
registradas en `sanfelipe/registro_protocolo.txt` antes de la ejecución
(6 de octubre de 2026, 05:14:13 UTC); se pueden comprobar con:

```sh
cd experimentos/sanfelipe
sha256sum PROTOCOLO.md generador_sanfelipe.py experimento.py verificar_generador.py exportar_datos.py
# comparar con registro_protocolo.txt (allí la carpeta figura con su nombre
# anterior, sintetico_sanfelipe/; el nombre no altera las huellas)
```

Contenido: protocolo, desviaciones, generador, datos de las 15 instancias en
CSV, resultados crudos y soluciones de las 330 ejecuciones de cada variante,
óptimos certificados en n = 7, resúmenes con los criterios C1 a C5 y las
figuras 6 y G1. Entorno registrado: Python 3.11.15, NumPy 2.4.4, PyGAD 3.7.0
y PuLP 2.9.0 (`resumen_*.json`, clave `entorno`).

## Código importado: reimplementación de `core/` y `poc_cap3/`

El código del paquete importa, sin copiarlas, las implementaciones de los
candidatos y el núcleo con los que se ejecutó, cuyas huellas también figuran
en `registro_protocolo.txt`. **Esos archivos originales no se conservaron.**
Para que el paquete pueda ejecutarse desde el repositorio se escribió una
reimplementación (17 de octubre de 2026) a partir del capítulo III:

| Ruta | Contenido | Estado |
|---|---|---|
| [`poc_cap3/`](poc_cap3/README.md) (`metodos.py`, `exhaustivo.py`, `validador.py`, `requirements.txt`) | los cuatro candidatos, la enumeración exhaustiva y el validador | **reimplementación**; huellas distintas de las registradas |
| [`../core/`](../core/README.md) (`domain.py`, `conflicts.py`, `fitness.py`, `repair.py`, `scheduler.py`) | núcleo Python del algoritmo genético | **reimplementación**; idem |

Como sus huellas son otras, la reimplementación **no acredita lo ejecutado**:
los resultados de `sanfelipe/` siguen siendo la evidencia registrada de la
ejecución con el código original. Lo que sí se comprobó contra esa evidencia:

| Comprobación | Resultado |
|---|---|
| F, J, Φ, validador, componentes e indicadores de las 1 320 soluciones registradas | coinciden las 1 320 |
| Óptimos de n = 7 (F y hojas factibles) | coinciden los 12 |
| Voraz (cromosoma) y PLE (F) en las 15 instancias | coinciden; 2 cromosomas de la PLE son óptimos alternativos con la misma F |
| Búsqueda tabú y AG | no repiten las ejecuciones registradas (otro consumo de números aleatorios) |
| Repetición completa (`sanfelipe/reimplementacion/`) | mismo orden que el registrado en v1, v2 y v2D; en v1D se invierte el orden entre PLE y AG por el criterio de tiempo C4 |

## Material suplementario (2026-10-17)

Agregado después de la ejecución y registrado en `sanfelipe/DESVIACIONES.md`:

| Archivo | Qué hace |
|---|---|
| `sanfelipe/reevaluar_cromosomas.py` | reevalúa las soluciones registradas y los óptimos de n = 7 |
| `sanfelipe/incertidumbre_bootstrap.py` → `sanfelipe/incertidumbre_brecha.csv` | intervalos bootstrap de la brecha media (C1) y de la diferencia AG − PLE, solo con resultados registrados |
| `sanfelipe/repetir_reimplementacion.py` → `sanfelipe/reimplementacion/` | repetición completa con la reimplementación, sin sobrescribir los resultados registrados |
| `poc_cap3/verificar_reimplementacion.py` | voraz, PLE y determinismo de búsqueda tabú y AG frente a lo registrado |

La integración continua (`.github/workflows/ci.yml`, trabajo «Experimento
Python») comprueba en cada cambio las huellas de los archivos registrados, la
reevaluación, la verificación y que `datos/` e `incertidumbre_brecha.csv` se
regeneran sin cambios.

## Relación con el prototipo Dart

El sistema (paquetes `dominio`, `servidor` y `cliente`) implementa en Dart el
algoritmo genético de la sección 3.4. Su herramienta
`paquetes/dominio/tool/experimento.dart` compara solo el AG y el voraz del
prototipo sobre otras instancias sintéticas: sirve para verificar la
implementación Dart y **no es una repetición** de la matriz de decisión de
esta carpeta. Cada experimento conserva por separado su entorno, su versión y
su evidencia.
