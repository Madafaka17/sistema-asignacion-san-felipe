# O-01 · Ficha de observación del despacho (Anexo C)

Registra cómo se forma la cola, qué unidad corresponde a cada salida y cómo se
asignan los conductores, incluidas las excepciones. Alcance previsto: dos
semanas de observación de colas y salidas en el terminal de Soritor. El
formato está listo; la observación no se ha realizado. Plantilla:
[`o01_observacion_despacho.csv`](o01_observacion_despacho.csv).

| Campo a observar | Registro requerido | Símbolo del modelo |
|---|---|---|
| Fecha y rango horario | hora de inicio y de fin de la observación | — |
| Destino o cola | Soritor–Moyobamba, Soritor–Tarapoto u otra | cola de `r(s)` |
| Unidad | código o placa anonimizada | `v` |
| Hora de llegada a la cola | hh:mm | orden de llegada |
| Posición en la cola | 1, 2, 3, … | `π(s)` |
| Conductor habitual | código anonimizado o «sin conductor habitual» | `c_hab(v)` |
| Reemplazos autorizados disponibles | códigos anonimizados | `C_v^R` |
| Hora de asignación del conductor | hh:mm | — |
| Momento de llenado | hh:mm, si aplica | salida nominal |
| Hora real de salida | hh:mm | `t_{s,a}` y `Δt(s)` |
| ¿Se respetó la cola? | sí o no; motivo | `σ(s)` |
| ¿Hubo reemplazo? | sí o no; motivo y autorización | `η(s)` |
| Incidencia | retraso, indisponibilidad, mantenimiento, ausencia u otra | HU-10 |
| Observación | descripción breve de la decisión del personal de despacho | — |

Los códigos de unidad y de conductor deben anonimizarse; no se registran
nombres, documentos de identidad ni teléfonos.
