# E-01 · Guía de entrevista al encargado de operaciones (Anexo D)

**Objetivo:** confirmar las reglas operativas que afectan directamente al
modelo y cerrar las observaciones pendientes del capítulo III.
**Entrevistado:** encargado de operaciones designado por la empresa (nombre y
cargo por confirmar). **Fecha, lugar, duración y constancia:** por registrar
al aplicar la entrevista.

| # | Pregunta | Qué ajusta en el sistema |
|---|---|---|
| 1 | ¿Cómo se forma la cola de unidades: una cola por destino, una cola general o ambas? | cola por destino de `r(s)` |
| 2 | ¿Qué criterio determina qué unidad «corresponde» para la siguiente salida? | `v0(s)` |
| 3 | Cuando dos unidades llegan al mismo tiempo, ¿cómo se resuelve el orden? | posición en la cola `π(s)` |
| 4 | ¿Cada unidad tiene un conductor habitual? ¿En qué casos esa relación es obligatoria? | conductor habitual `c_hab(v)` |
| 5 | ¿Qué conductores pueden reemplazar al conductor habitual de cada unidad y quién autoriza el reemplazo? | reemplazos autorizados `C_v^R` |
| 6 | ¿Qué sucede cuando la primera unidad de la cola no tiene conductor disponible? | `v1(s)` |
| 7 | ¿Está permitido utilizar la siguiente unidad de la cola? ¿Bajo qué condiciones? | uso de `v1(s)` en `A_s` |
| 8 | ¿El equilibrio de carga debe medirse solo entre los conductores que trabajan en el turno o entre todos los disponibles? | definición de `D(X)` (Anexo F) |
| 9 | ¿Qué prioridad deben tener retrasos, reprogramaciones, tiempo muerto y equilibrio de carga? ¿Deben penalizarse los saltos de cola y los reemplazos? | pesos `w_j` de `J(X)` |
| 10 | ¿Los tiempos Soritor–Moyobamba (30 min) y Soritor–Tarapoto (150 min) son de ida o de ida y vuelta? | duración del ciclo de la ruta |
| 11 | ¿Qué significan exactamente 37 unidades diarias, 44 conductores y 16 asientos, y siguen vigentes? | escala de la flota y `Q_v` |
| 12 | ¿Qué representa un «servicio programado» en las Tablas 2 y 3 y cuál es el origen de los valores de 2021 a 2025? | línea base de los indicadores |
| 13 | ¿Quién revisará y aprobará las programaciones propuestas por el sistema? (Product Owner) | rol `operaciones` |
| 14 | ¿Qué información debe mostrar el reporte para aprobar o rechazar una propuesta? | pantalla de revisión (HU-08) |
| 15 | ¿Una unidad sale solo al completar sus pasajeros o también por horario o tiempo máximo de espera? ¿Qué hora es la salida nominal? | salida nominal y `Δt(s)` |

Las respuestas se registran por escrito, con la conformidad del entrevistado,
y se usan para ajustar las reglas de `A_s`, los pesos de `J`, la definición de
`D` y los requisitos de la sección 3.8.
