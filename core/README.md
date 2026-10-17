# `core/` — núcleo Python del algoritmo genético (reimplementación)

**Esta carpeta no contiene los archivos con los que se ejecutó el experimento del
Anexo E.** Esos archivos no se conservaron. Esta es una **reimplementación escrita
el 17 de octubre de 2026** a partir del capítulo III de la tesis (secciones 3.1.2,
3.1.7 y 3.4), de la interfaz que usa el paquete
[`experimentos/sanfelipe/`](../experimentos/sanfelipe/) y de la función
`_loss_components` que conserva `sensibilidad_D.py`. Sus huellas SHA-256 **no son**
las de la Tabla E2, registradas en
[`registro_protocolo.txt`](../experimentos/sanfelipe/registro_protocolo.txt):
cualquiera puede comprobar que difieren.

| Módulo | Contenido | Sección |
|---|---|---|
| `domain.py` | `AdmissibleTriple`, `Service`, `Instance` | 3.1.2, ec. (1) a (3) y (15) |
| `conflicts.py` | Γ: pares de alternativas en conflicto | ec. (4) |
| `fitness.py` | F(X), J(X), Φ(X), E(X) y sus componentes | ec. (7) y (8) |
| `repair.py` | reparación dirigida, como `paquetes/dominio/lib/src/optimizacion/reparacion.dart` | 3.4.9 |
| `scheduler.py` | algoritmo genético sobre PyGAD 3.7.0 | 3.4.1 a 3.4.11, Tabla 22 |

## Qué reproduce y qué no

Se comprobó contra los archivos registrados del paquete (no contra el código
original, que no existe):

| Comprobación | Resultado | Cómo repetirla |
|---|---|---|
| F, J, Φ, validador, E, Ret, R, Tm, D e indicadores operativos de las 1 320 soluciones registradas (v1, v2, v1D, v2D) | **coinciden las 1 320** en los 16 campos | `experimentos/sanfelipe/reevaluar_cromosomas.py` |
| Óptimo de n = 7 por enumeración exhaustiva: F y hojas factibles | **coinciden los 12** | idem |
| Número de pares de Γ por instancia (`datos/resumen_instancias.csv`) y factibilidad de la programación oculta | **coinciden las 15 instancias**; `datos/*.csv` se regeneran idénticos | `verificar_generador.py`, `exportar_datos.py` |
| Voraz: cromosoma de cada instancia | **15 de 15** iguales en v1 y en v2 | `experimentos/poc_cap3/verificar_reimplementacion.py` |
| PLE: F de cada instancia | **15 de 15** iguales; 13 cromosomas iguales y 2 óptimos alternativos con la misma Z y la misma F | idem |
| Búsqueda tabú y AG: cromosoma de cada ejecución | **no se reproducen**: consumen los números aleatorios de otra forma que el original; con la misma semilla, cada ejecución de la reimplementación sí se repite exactamente | idem; `repetir_reimplementacion.py` |

Por eso los resultados registrados del Anexo E siguen siendo **evidencia de lo
ejecutado con el código original** y la repetición con esta reimplementación se
informa aparte (`experimentos/sanfelipe/reimplementacion/`).

## Uso

```python
from core.conflicts import build_conflict_pairs
from core.fitness import evaluate
from core.repair import repair
from core.scheduler import GAConfig, run_ga

servicios = instancia.services_with_options()
pares = build_conflict_pairs(servicios, min_transition=10.0)
resultado = run_ga(instancia, 10.0, GAConfig(seed=1))
print(evaluate(resultado.chromosome, instancia, pares))
```

Dependencias: [`experimentos/poc_cap3/requirements.txt`](../experimentos/poc_cap3/requirements.txt).

## Relación con el sistema

El sistema (`paquetes/dominio`, `servidor`, `cliente`) usa su propio núcleo en
Dart, no este. Esta carpeta existe solo para que el paquete del experimento pueda
ejecutarse desde el repositorio.
