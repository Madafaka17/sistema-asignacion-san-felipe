# `experimentos/poc_cap3/` — candidatos, enumeración exhaustiva y validador (reimplementación)

**Esta carpeta no contiene los archivos con los que se ejecutó el experimento del
Anexo E.** Esos archivos no se conservaron. `metodos.py`, `exhaustivo.py` y
`validador.py` son una **reimplementación escrita el 17 de octubre de 2026** a
partir de las secciones 3.1.4 a 3.1.7, 3.2.3 y de las Tablas 17 y 18 de la tesis.
Sus huellas SHA-256 **no son** las registradas en
[`../sanfelipe/registro_protocolo.txt`](../sanfelipe/registro_protocolo.txt).

| Archivo | Contenido |
|---|---|
| `metodos.py` | `resolver_voraz` (ec. 12), `resolver_ple` (ec. 9 a 11, PuLP 2.9.0 con CBC), `resolver_tabu` (ec. 13 y 14) y `resolver_ag` (núcleo `core/`) |
| `exhaustivo.py` | óptimo certificado por enumeración con poda (referencia de C1 en n = 7) |
| `validador.py` | validador independiente de Φ: no usa Γ ni la función de aptitud |
| `verificar_reimplementacion.py` | compara la reimplementación con los resultados registrados |
| `requirements.txt` | NumPy 2.4.4, PyGAD 3.7.0 y PuLP 2.9.0, como en el entorno registrado (Python 3.11.15) |

Qué reproduce exactamente y qué no: ver [`../../core/README.md`](../../core/README.md).
En resumen, la evaluación, el validador, la enumeración exhaustiva, el voraz y la F
de la PLE coinciden con lo registrado; la búsqueda tabú y el AG no repiten las
ejecuciones registradas.

## Decisiones que el texto de la tesis no fija

Se tomaron para reproducir los resultados registrados y se comprobaron con ellos:

- **Voraz.** Los choques se cuentan en la tabla de ocupación: cada intervalo ya
  asignado al vehículo o al conductor que se cruza con la alternativa cuenta uno,
  y exceder el límite de conducción cuenta uno más; en empate se elige la
  alternativa más temprana. Con esta regla los 15 cromosomas son los registrados.
- **PLE.** Variables `x_i_k` binarias; `ini_v`, `fin_v` ∈ [0, H]; `tm_v`, `Lmáx` ≥ 0;
  CBC con un hilo y 300 s. El orden en que se agregan las restricciones —(3), (10),
  (5), (11) y (6)— solo decide cuál de los óptimos alternativos devuelve CBC; con
  él, la F de las 15 instancias es la registrada.
- **Búsqueda tabú.** `random.Random(semilla)`; cada vecino es un servicio con más
  de una alternativa y otra alternativa suya, elegidos al azar; el presupuesto
  cuenta la evaluación de la solución inicial.
- **AG.** Población inicial con `numpy.random.default_rng(semilla)`; PyGAD elige
  por torneo tantos progenitores como la población y forma cada descendiente con
  los progenitores k y k + 1; la reparación se aplica al final de la mutación, de
  modo que todo descendiente se repara antes de evaluarse.

## Lo que sigue sin recuperarse

Los registros de la **prueba técnica inicial** que la tesis cita como
`experimentos/poc_cap3/PROTOCOLO.md` (sección 8) y `experimentos/poc_cap3/resumen.json`
no se reconstruyen: eran resultados de una ejecución, no código, y escribirlos de
nuevo sería inventarlos.
