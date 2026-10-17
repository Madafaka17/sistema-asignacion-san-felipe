# Instrumentos de levantamiento (sección 3.8.1 de la tesis)

Formatos de los instrumentos con los que se validarán, en la empresa, las
cifras del diagnóstico y las reglas de despacho que usa el modelo (cola por
destino, conductor habitual, reemplazos autorizados, salida nominal). Todos
trabajan con **códigos anonimizados**: nunca nombres, placas, DNI ni teléfonos.

| Código | Instrumento | Archivo | Estado (tesis, anexos A–D) |
|---|---|---|---|
| RD-01 | Extracción de registros históricos | [`rd01_registros_historicos.md`](rd01_registros_historicos.md), [`rd01_registros_historicos.csv`](rd01_registros_historicos.csv) | formato listo; revisión documental no realizada |
| RD-02 | Manifiestos de pasajeros revisados | [`rd02_manifiestos.md`](rd02_manifiestos.md), [`rd02_manifiestos.csv`](rd02_manifiestos.csv) | 11 manifiestos revisados y anonimizados |
| O-01 | Ficha de observación del despacho | [`o01_observacion_despacho.md`](o01_observacion_despacho.md), [`o01_observacion_despacho.csv`](o01_observacion_despacho.csv) | formato listo; observación no realizada |
| E-01 | Guía de entrevista al encargado de operaciones | [`e01_entrevista_operaciones.md`](e01_entrevista_operaciones.md) | guía lista; entrevista no realizada |

Relación con el sistema: las respuestas de E-01 y las observaciones de O-01
fijan las reglas de `A_s` (cola y pares autorizados), los pesos `w_j` y la
definición de `D` en `config/parametros.yaml`; RD-01 y RD-02 alimentan la
línea base de los indicadores (PIO, PSR, PSA). Las copias fotográficas de
los manifiestos las conserva el autor y no se publican.
