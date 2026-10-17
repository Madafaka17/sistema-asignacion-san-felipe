# RD-02 · Manifiestos de pasajeros revisados (Anexo B)

Revisión de los manifiestos que la empresa emite para las salidas desde el
terminal de Soritor. Se revisaron **once** manifiestos; antes de cualquier uso
se ocultaron los nombres, documentos de identidad y edades de los pasajeros y
los nombres de los conductores. Los códigos de unidad y de conductor
sustituyen a la placa y al nombre. Datos en
[`rd02_manifiestos.csv`](rd02_manifiestos.csv).

| N.° de manifiesto | Fecha consignada | Hora | Destino | Asientos | Pasajeros en origen | Unidad | Conductor |
|---|---|---|---|---:|---:|---|---|
| 001-029451 | 24 de set. (sin año) | 4:00 a. m. | Tarapoto | 16 | — | V004 | C002 |
| 001-029455 | 25 de set. (sin año) | 4:00 a. m. | Tarapoto | 16 | 12 | V003 | C037 |
| 001-029458 | 26-09-26 | 4:00 a. m. | Tarapoto | 16 | 16 | — | — |
| 001-029459 | 27-09-26 | 4:00 a. m. | Tarapoto | 16 | — | s. c. | C003 |
| 001-029460 | 28-09-26 | 4:00 a. m. | Tarapoto | 16 | — | s. c. | C040 |
| 001-029461 | 28-09-26 | 4:00 a. m. | Tarapoto | 16 | — | s. c. | C017 |
| 001-029462 | 27-09-26 | 4:00 a. m. | Tarapoto | 16 | — | V002 | C035 |
| 001-029467 | 30-09-26 | 4:00 a. m. | Tarapoto | 16 | — | — | — |
| 001-029468 | 01-10-26 | 4:00 a. m. | Tarapoto | 16 | — | s. c. | C021 |
| 001-029471 | 02-10-26 | 4:00 a. m. | Tarapoto | 16 | 16 | V002 | C035 |
| 001-029483 | 03-10-26 | 4:00 a. m. | Tarapoto | 16 | 15 | V001 | C041 |

Origen: Soritor en todos los casos. «—»: dato no consignado o no legible (no
se registra como cero). «s. c.»: placa consignada, aún sin código en el
catálogo de unidades.

Lo que permiten verificar: cada salida se documenta con número correlativo,
fecha, hora, unidad, conductores y pasajeros, aunque varios campos no siempre
se completan; los once consignan **16 asientos**; la misma unidad (V002)
aparece con el mismo conductor (C035) en dos manifiestos, consistente con la
regla del conductor habitual `c_hab(v)` del modelo (Tabla 11).
