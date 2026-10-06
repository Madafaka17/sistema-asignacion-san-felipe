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
| `ruta` | `R`; duración estimada `d` = `duracion_min` | `codigo` único | HU-04 |
| `ruta_vehiculo` | `κ(v, r) = 1` (N:M) | PK (`ruta_id`, `vehiculo_id`) | HU-04 |
| `salida_autorizada` | elementos de `H_s`; `d_{s,h}` = `duracion_min` si la salida tiene una duración propia | único (`ruta_id`, `hora`) | HU-05 |
| `servicio` | `S`; `r(s)` = `ruta_id`; `p_s` = `prioridad`; `q_s` = `capacidad_requerida` | **FK compuesta** (`ruta_id`, `hora_solicitada`) → `salida_autorizada`; `CHECK prioridad BETWEEN 1 AND 3` | HU-06 |
| `programacion` | una ejecución del método: `F(X)` = `aptitud`, `Φ(X)` = `phi`, `phi_validador`, componentes `Cv`, `Cc`, `N_exc`, `E`, `Ret`, `R`, `Tm`, `D`, `J`; copia de los parámetros (`JSON`) | **único** sobre la columna generada `fecha_aprobada` (una aprobada por día) | HU-07, HU-09 |
| `asignacion` | `x_{s,a} = 1` (vehículo, conductor, salida, fin) o `u_s = 1` (`estado = 'incidencia'` con `motivo`) | único (`programacion_id`, `servicio_id`); `CHECK` de coherencia entre estado y recursos | HU-07 a HU-09 |
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
ficticios (6 vehículos, 7 conductores —uno con la licencia vencida y otro no
disponible—, 3 rutas desde Soritor, 23 salidas y 12 servicios para el día
siguiente) y los tres usuarios de demostración. No contiene datos reales de
personas.
