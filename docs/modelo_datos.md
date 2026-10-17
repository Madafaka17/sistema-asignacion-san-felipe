# Modelo de datos

El esquema está en [`basedatos/esquema.sql`](../basedatos/esquema.sql)
(MySQL 8.4, InnoDB, `utf8mb4`). Cada tabla corresponde a un conjunto o a un
parámetro de la Tabla 11 de la tesis, de modo que leer la base de datos es
leer el modelo matemático. El diagrama entidad–relación está en
[`uml.md` §11](uml.md#11-entidadrelación).

## Tablas ↔ conjuntos y parámetros del modelo

| Tabla | Elemento del modelo | Columnas clave | HU |
|---|---|---|---|
| `vehiculo` | `V`; `Q_v` = `capacidad`; `E_v = 1` ⇔ `estado = 'operativo'` | `codigo` y `placa` únicos; `CHECK capacidad > 0` y formato de placa | HU-02 |
| `conductor` | `C`; `T_c` = [`turno_inicio`, `turno_fin`]; `H_c0` = `minutos_acumulados`; `H_cmáx` = `limite_minutos`; `E_c` = `disponible` ∧ licencia vigente | `dni` único (`CHECK` 8 dígitos); `CHECK turno_inicio < turno_fin` | HU-03 |
| `par_autorizado` | `chab(v)` (`tipo = 'habitual'`) y `C_v^R` (`tipo = 'reemplazo'`) | PK (`vehiculo_id`, `conductor_id`); **únicos** sobre las columnas generadas `habitual_vehiculo` y `habitual_conductor`: un habitual por unidad y una unidad por habitual | HU-02, HU-03 |
| `ruta` | `R`; `d` = `duracion_min`, el **viaje redondo** (ida, estancia y retorno); `ida_min` = ida declarada por la empresa (30 y 150 min), solo como referencia | `codigo` único; `CHECK 2 · ida_min ≤ duracion_min` | HU-04 |
| `ruta_vehiculo` | `κ(v, r) = 1` (N:M) | PK (`ruta_id`, `vehiculo_id`) | HU-04 |
| `salida_autorizada` | elementos de `H_s`; `d_{s,h}` = `duracion_min` si la salida tiene una duración propia | único (`ruta_id`, `hora`) | HU-05 |
| `cola` | cola de despacho de una ruta (su origen es el terminal) para una fecha | único (`ruta_id`, `fecha`); su fila se bloquea al registrar una llegada | HU-02, HU-06 |
| `entrada_cola` | llegada de una unidad: `π` = `posicion`, por orden de llegada; `activa = FALSE` si dejó la cola | único (`cola_id`, `posicion`); las entradas no se borran ni se reordenan | HU-02, HU-06 |
| `servicio` | `S`; `r(s)` = `ruta_id`; `p_s` = `prioridad`; `q_s` = `capacidad_requerida`; salida nominal = `hora_solicitada`; turno en la cola = `entrada_cola_id` (`v0(s)`, `π(s)`) | **FK compuesta** (`ruta_id`, `hora_solicitada`) → `salida_autorizada`; **único** sobre la columna generada `entrada_vigente` (un turno por servicio no cancelado); `CHECK prioridad BETWEEN 1 AND 3` | HU-06 |
| `snapshot_entrada` | entrada de una ejecución o de un ajuste: el `DatosTurno` en JSON canónico y su SHA-256 | **único** `sha256`; `CHECK (sha256 = SHA2(contenido, 256))`; solo se inserta | HU-07, HU-09 |
| `programacion` | una versión de una ejecución del método: `F(X)` = `aptitud`, `Φ(X)` = `phi`, `phi_validador`, componentes `Cv`, `Cc`, `N_exc`, `E`, `Ret`, `R`, `Tm`, `D`, `J`; copia de los parámetros (`JSON`), semilla, `version_algoritmo`, `tiempo_ms` (solicitud) y `tiempo_nucleo_ms` (núcleo); `version`, `ejecucion_id` (la versión 1), `version_anterior_id` y `snapshot_id` | **único** sobre la columna generada `fecha_aprobada` (una aprobada por día) y sobre (`ejecucion_id`, `version`); estado `sustituida` para la versión que un ajuste reemplazó | HU-07, HU-09 |
| `asignacion` | `x_{s,a} = 1` (vehículo, conductor, salida, fin) o `u_s = 1` (`estado = 'incidencia'` con `motivo`); `σ(s)` = `salto_cola`, `η(s)` = `reemplazo`, `Δt(s)` = `demora_min`, con `v0(s)` (`vehiculo_cola_id`), `chab(v)` (`conductor_habitual_id`) y la `justificacion` | único (`programacion_id`, `servicio_id`); `CHECK` de coherencia entre estado y recursos | HU-07 a HU-09 |
| `historial_aptitud` | curva de convergencia: mejor y promedio de `F` por generación | PK (`programacion_id`, `generacion`) | HU-07 |
| `incidencia` | retrasos, reprogramaciones e indisponibilidades: fuente de PIO, PSR y PSA | índice (`fecha`, `tipo`); `CHECK` minutos de retraso | HU-10, HU-11 |
| `usuario`, `sesion` | control de acceso | resumen PBKDF2; SHA-256 del token de actualización | HU-01 |
| `bitacora` | quién hizo qué y cuándo | `detalle JSON`, `fecha_hora DATETIME(3)` | RNF-06 |

La **programación comprometida** `b(s)` es la asignación del servicio en la
programación aprobada de su fecha (`RepositorioProgramaciones.comprometidas`).

## Decisiones del esquema

* **Horas en minutos** (`SMALLINT`): el modelo usa `t ∈ [0, 1440)`; se evita
  convertir `TIME` en cada consulta y en cada evaluación de `F`.
* **Reglas del modelo en la base.** La FK compuesta de `servicio` impide
  registrar un servicio a una hora no autorizada aunque se salte la API; el
  índice único sobre `fecha_aprobada` impide dos programaciones aprobadas el
  mismo día; los `CHECK` repiten las validaciones de la lógica de negocio
  como última defensa.
* **Cola por orden de llegada.** Cada llegada recibe la posición siguiente a
  la última de su cola dentro de una transacción que bloquea la fila de
  `cola` (`SELECT … FOR UPDATE`): dos registros simultáneos no pueden tomar la
  misma posición. Retirar una unidad desactiva su entrada sin borrarla, de
  modo que la cola conserva su historia; un índice único sobre una bandera
  `activa` no bastaría (sección 5.5 de la tesis).
* **Restricciones con columnas generadas.** Igual que `fecha_aprobada`,
  `servicio.entrada_vigente` y `par_autorizado.habitual_*` valen `NULL` fuera
  del caso que restringen, y un índice único sobre ellas expresa la regla
  («un turno, un servicio vigente»; «un habitual por unidad»). Por eso las
  claves foráneas de `par_autorizado` no usan `ON DELETE CASCADE`, que MySQL
  no admite sobre columnas base de una columna generada.
* **Procedencia.** Cada versión apunta al snapshot de la entrada con la que
  se construyó su instancia; con él, la semilla, los parámetros y
  `version_algoritmo` la ejecución puede repetirse. La huella se verifica en
  la propia base (`CHECK` con `SHA2`): un `UPDATE` que cambie el contenido
  sin la huella correspondiente falla.
* **Versiones.** Un ajuste no modifica la versión revisada: la copia como la
  versión siguiente (`INSERT … SELECT`), aplica el cambio sobre la copia y
  marca la anterior como `sustituida`, todo en una transacción que bloquea
  la fila de la versión ajustada.
* **Historial completo.** Cada ejecución del método crea un registro; la
  aprobada pasa a `reemplazada` cuando se aprueba otra. Así se miden PAV y el
  tiempo medio de generación sobre todas las ejecuciones (HU-11).
* **Integridad transaccional.** Generar, ajustar y aprobar escriben varias
  tablas en una sola transacción (`BaseDatos.transaccion`).
* **Seguridad.** Nada sensible en claro: contraseñas con PBKDF2-HMAC-SHA256
  (100 000 iteraciones) y tokens de actualización como SHA-256. El usuario de
  la aplicación solo tiene permisos sobre su base (`GRANT … ON sanfelipe.*`).
* **Sin ORM.** Los repositorios escriben SQL con parámetros con nombre
  (`:fecha`); el conector escapa cada valor (sin concatenar datos del usuario).

## Datos de demostración

[`basedatos/datos_ejemplo.sql`](../basedatos/datos_ejemplo.sql) carga datos
ficticios con la estructura declarada por la empresa: 10 unidades de 16
asientos (V-10 en mantenimiento después de formar cola), 12 conductores
—C-10 no disponible, C-11 con la licencia vencida y C-12 con una licencia
que no habilita la categoría M2—, sus pares habitual/reemplazo, las rutas
Soritor–Moyobamba (ida declarada de 30 min; viaje redondo supuesto de 90) y
Soritor–Tarapoto (150 min; 330), salidas cada 30 min, las colas del día
siguiente (16 llegadas, con turnos libres para registrar servicios) y 12
servicios con su turno en la cola. Los viajes redondos, las horas, los
turnos y las llegadas son supuestos de demostración, no datos de la
empresa. No contiene datos reales de personas.
