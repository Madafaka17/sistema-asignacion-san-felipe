# Métodos, modelos y algoritmos

Resumen de la lógica principal del sistema y de sus modelos de datos. La
derivación completa de un método (ecuación → pseudocódigo → código, con su
complejidad) está en [`formalizacion_algoritmo.md`](formalizacion_algoritmo.md);
el diseño del algoritmo genético, en
[`teoria_algoritmo_genetico.md`](teoria_algoritmo_genetico.md).

## 1. Problema

Cada día la empresa debe decidir, para cada **servicio** del turno (una
salida de una ruta autorizada con su prioridad y sus asientos requeridos),
qué **vehículo**, qué **conductor** y qué **salida autorizada** lo cubren, de
modo que:

* **restricciones duras** (no negociables): vehículo operativo, compatible con
  la ruta y con capacidad suficiente; conductor disponible, con licencia
  vigente y habilitante, dentro de su turno; ningún vehículo ni conductor en
  dos servicios a la vez ni con menos de `t_mín` = 10 min entre ellos; ningún
  conductor por encima de su límite de conducción;
* **criterios blandos** (se minimizan): retraso y reprogramación respecto de
  la programación ya comprometida, tiempo muerto de la flota y desequilibrio
  de la carga de los conductores.

## 2. Modelo matemático (capítulo III de la tesis)

| Ecuación | Contenido | Implementación |
|---|---|---|
| (1) | alternativas admisibles `A_s`, con las reglas de cola `v ∈ {v0(s), v1(s)}` y de conductores `c ∈ {chab(v)} ∪ C_v^R` (sección 3.1.2) | `ConstructorInstancia.construir` |
| Tabla 11 | salidas `σ(s)` (salto de cola), `η(s)` (reemplazo) y `Δt(s)` (demora), fuera de `F(X)` | `ExcepcionesAsignacion` |
| (2)–(3) | decisión binaria `x_{s,a}` y asignación única | un gen por servicio (cumple (3) por construcción) |
| (4)–(5) | pares en conflicto Γ con holgura `t_mín` | `enConflicto` (Γ implícito) |
| (6) | límite de conducción `H_c0 + ℓ_c ≤ H_cmáx` | `Evaluador` (E, N_exc) y `Reparador` paso 2 |
| (7)–(8) | `F(X) = −[M·Φ + E + J]`, `J` = suma ponderada normalizada de Ret, R, Tm y D | `Evaluador.evaluarProgramacion` |
| (12) | regla voraz: la alternativa más temprana compatible | `AlgoritmoVoraz` |
| (15) | cromosoma `α_s ∈ {0, …, |A_s| − 1}` | `List<int>` |
| (19)–(23) y Tabla 24 | indicadores PIO, PSR, PSA, PUV, PAV y los operativos `Ση`, `Σσ`, salidas demoradas, `ΣΔt`, `Ret`, `Tm` | `Indicadores` y `ReporteServicio` |

## 3. Lógica principal: generar, revisar y aprobar (HU-07 a HU-09)

`servidor/lib/src/servicios/programacion_servicio.dart`:

1. **Precondición.** Si el turno no tiene servicios pendientes, responde 422
   «No hay servicios pendientes para el turno seleccionado» sin ejecutar el
   método.
2. **Instancia.** Lee con los repositorios los servicios del día, la flota,
   los conductores, las rutas, las salidas, las colas de despacho de la
   fecha, los pares autorizados y la programación comprometida `b(s)`, y
   aplica la ecuación (1): cada servicio con turno en la cola solo admite la
   unidad que corresponde o la siguiente elegible, y cada unidad solo su
   conductor habitual o un reemplazo autorizado. Los servicios sin
   alternativas quedan con su motivo («La unidad que corresponde en la cola
   (V-10, posición 2) dejó la cola…», «La unidad V-05 no tiene conductor
   habitual ni reemplazos autorizados registrados»…).
3. **Optimización.** `FabricaEstrategias.crear(parametros.metodo)` devuelve el
   algoritmo genético (o el voraz) configurado en `config/parametros.yaml`, que
   se ejecuta en un isolate con límite `t_lím` = 300 s.
4. **Decodificación.** `Decodificador` convierte el mejor cromosoma en
   asignaciones; si queda un conflicto residual, el servicio de menor
   prioridad pasa a incidencia con el motivo, de modo que lo asignado tiene
   Φ = 0.
5. **Validación independiente.** `Validador` recalcula Φ por barrido de
   intervalos; su valor (`phi_validador`) es el que decide si se puede aprobar.
   `ExcepcionesAsignacion` calcula `σ`, `η` y `Δt` de cada asignación y
   explica por qué el sistema propone un salto o un reemplazo.
6. **Persistencia.** En una transacción: snapshot de la entrada (JSON
   canónico y SHA-256), programación versión 1 (con F, Φ, componentes,
   tiempo de la solicitud y del núcleo, semilla, parámetros efectivos y
   método@versión del núcleo), asignaciones, curva de convergencia y evento
   de bitácora. Responde 201.
7. **Ajuste (HU-09, CU-12).** Solo se acepta una alternativa de `A_s`; si
   salta la cola, reemplaza al conductor habitual o demora la salida exige
   el motivo; se revalida toda la programación y los cruces quedan marcados
   como `conflicto`. El resultado es una **versión nueva** con su snapshot;
   la versión ajustada queda `sustituida` y ya no se ajusta ni se aprueba
   (409).
8. **Aprobación (HU-09, CU-09).** Bloquea la fila de la versión y verifica
   que siga vigente; exige Φ = 0 según el validador; reemplaza la
   aprobada anterior de la fecha, pasa los servicios asignados a
   `programado` y registra usuario, fecha y hora en la bitácora, con cada
   salto de cola, reemplazo o demora aprobados y su motivo (sección 3.6).

## 4. Algoritmos

| Algoritmo | Archivo | Idea | Complejidad |
|---|---|---|---|
| Construcción de `A_s` | `constructor_instancia.dart` | filtra V × C × H_s con las condiciones de (1), incluidas la cola y los pares | `O(n·(q + |H_s|·|V|·|C|))`, `q` = entradas de la cola |
| Evaluación de F | `evaluador.dart` | conflictos entre las alternativas elegidas, cargas, Tm por vehículo, desviación | `O(n² + n log n)` |
| Algoritmo genético | `algoritmo_genetico.dart` | Tabla 22: torneo k = 3, cruce uniforme (p_c = 0,8), mutación de un gen (p_m = 0,1), reparación, elitismo 10 %, paradas por G_máx, convergencia y tiempo | `O(G·P·(n² + ϱ·(n² + c·k·n)))` |
| Reparación dirigida | `reparacion.dart` | conserva el servicio de mayor prioridad y reasigna el otro; luego corrige excesos de conducción; ≤ 5 pasadas, determinista | `O(n² + c·k·n)` por pasada |
| Voraz (línea base) | `algoritmo_voraz.dart` | ordena por hora y prioridad y toma la primera alternativa libre (ec. 12) | `O(n log n + K·n)` |
| Validador | `validador.dart` | barrido de intervalos ordenados por recurso | `O(n log n + m)` |
| Indicadores | `modelos/indicadores.dart` | porcentajes de las ecuaciones 19 a 23 | `O(1)` sobre los conteos SQL |

## 5. Modelos de datos

* **Persistencia:** tablas y su correspondencia con los conjuntos del modelo
  en [`modelo_datos.md`](modelo_datos.md); diagrama ER en
  [`uml.md` §11](uml.md#11-entidadrelación).
* **Contrato (cliente ⇄ servidor):** `paquetes/dominio/lib/src/modelos/`
  — `Vehiculo`, `Conductor`, `Ruta`, `SalidaAutorizada`, `ServicioProgramado`,
  `EntradaCola`, `ParAutorizado`, `ConductoresAutorizados`,
  `Programacion`, `Asignacion`, `ComponentesAptitud`, `Incidencia`,
  `ReporteIndicadores`, `Usuario`, `EntradaBitacora`; cada uno con `toJson` y
  un `fromJson` que valida tipos con `LectorJson`.
* **Núcleo (en memoria):** `InstanciaTurno`, `ServicioTurno`, `Alternativa`,
  `ConductorTurno`, `ResultadoOptimizacion`, `PuntoConvergencia`
  (diagrama en [`formalizacion_algoritmo.md` §5.1](formalizacion_algoritmo.md#51-en-memoria)).

## 6. Validaciones de negocio

| Historia | Regla | Respuesta |
|---|---|---|
| HU-01 | usuario `[a-z0-9._]{4,50}` único; contraseña ≥ 8 con letras y números | 409 / 422 |
| HU-02 | placa `ABC-123` única; código único; 1 a 100 asientos | 409 «La placa ya está registrada» / 422 |
| HU-03 | DNI de 8 dígitos único; turno dentro del día; no se marca disponible con licencia vencida | 409 / 422 «Licencia vencida» |
| HU-02, HU-03 (pares) | un habitual por unidad y una unidad por habitual; el habitual no es a la vez reemplazo; conductores existentes | 409 «C-01 ya es conductor habitual de V-05» / 422 |
| Cola de despacho | unidad operativa y compatible con la ruta; llegada no anterior a la última; la unidad no espera turno dos veces; posición asignada bajo bloqueo | 409 «La unidad V-01 ya espera turno en la posición 1 de la cola de R-01» / 422 |
| HU-04 | duración > 0 y < 24 h; si se registra la ida, el viaje redondo la cubre dos veces; vehículos compatibles existentes | 422 «La duración debe ser mayor que cero» |
| HU-05 | hora válida y no repetida en la ruta; no se borra una salida con servicios | 409 «La salida ya existe para esta ruta» |
| HU-06 | ruta activa obligatoria; hora = salida autorizada; prioridad 1–3; el turno de cola es de la misma ruta y fecha, sigue activo, llegó antes de la salida y no lo tiene otro servicio | 400 (campo `rutaId`) / 409 / 422 |
| HU-09 (ajuste) | alternativa de `A_s` (la cola y los pares incluidos); motivo obligatorio si salta la cola o reemplaza al habitual | 422 «Indique el motivo: el ajuste salta la cola (correspondía V-01)» |
| HU-10 | el servicio debe existir; retraso > 0 minutos | 404 «Servicio no encontrado» / 422 |
| HU-11 | `hasta ≥ desde`; sin programaciones aprobadas → «Sin datos para el periodo» | 422 / 200 |

## 7. Indicadores (sección 3.5)

| Indicador | Fórmula | Fuente |
|---|---|---|
| PIO | (vehículos + conductores inadecuados) / servicios programados × 100 | incidencias de indisponibilidad |
| PSR | servicios reprogramados / programados × 100 | incidencias de reprogramación |
| PSA | servicios con retraso / programados × 100 | incidencias de retraso |
| PUV | minutos de servicio / minutos disponibles de la flota × 100 | asignaciones aprobadas y `|V|` operativo |
| PAV | asignaciones sin conflicto / asignaciones generadas × 100 | todas las ejecuciones del método |
| Reemplazos autorizados | `Ση(s)` | asignaciones aprobadas |
| Saltos de cola | `Σσ(s)` | asignaciones aprobadas |
| Salidas demoradas | servicios con `Δt(s) > 0` | asignaciones aprobadas |
| Minutos de demora | `ΣΔt(s)` | asignaciones aprobadas |
| Retraso acumulado | `Ret(X)` | programaciones aprobadas |
| Tiempo muerto | `Tm(X)` | programaciones aprobadas |

Ejemplo de la Tabla 33: 190 servicios, 12 reprogramados y 9 con retraso dan
PSR = 6,3 % y PSA = 4,7 % (prueba `hu10_11_operacion_test.dart`).
