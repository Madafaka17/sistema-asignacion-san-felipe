# Caso real: salida del manifiesto 001-029483 (Soritor–Tarapoto, 03/10/2026)

Demostración del prototipo con una salida real de la empresa (tesis, sección 5.6.2; rúbrica del
EP3, criterio 15(b) y 15(d)). Ejecutada el **4/11/2026 de 20:10:54 a 20:13:08 UTC** (15:10 a
15:13, hora de Lima) con `herramientas/caso_real.sh`, que recorre la interfaz con
`cliente/integration_test/caso_real/caso_real_test.dart` sobre una base **vacía**: solo el
esquema y las tres cuentas del sistema, sin los datos de demostración. Resultado: **PASA**.

## Origen de los datos

La empresa autorizó por escrito, el 5/10/2026, el uso de los once manifiestos para
investigación (tesis, Anexo B, Figura B3). Se usó el manifiesto 001-029483 de la Tabla B1:

| Dato del caso | Valor | Origen |
|---|---|---|
| Código del servicio | 001-029483 | número del manifiesto (Tabla B1) |
| Fecha del turno | 03/10/2026 | manifiesto (03-10-26) |
| Ruta | Soritor – Tarapoto | manifiesto (destino Tarapoto, origen Soritor) |
| Salida autorizada y hora solicitada | 04:00 | hora consignada en el manifiesto (4:00 a. m.); la tesis advierte que esa hora figura en los once manifiestos y debe verificarse con O-01 |
| Asientos de la unidad | 16 | manifiesto |
| Asientos requeridos | 15 | pasajeros en origen del manifiesto |
| Unidad | V001 | código de la unidad en la Tabla B1 (la placa está oculta) |
| Conductor y par autorizado | C041, habitual de V001 | código del conductor de esa salida en la Tabla B1 |
| Ida declarada | 150 min | declaración de la empresa (sección 1.2) |
| Duración del viaje redondo | 330 min | **supuesto** de la tesis: 2 × 150 min + 30 min de estancia (sección 3.1.2) |
| Llegada de V001 a la cola | 03:30 | **supuesto**: no consignada; anterior a la salida, porque V001 salió primero |
| Licencia de C041 | A-IIb, vence 2027-10-03 | **supuesto**: no consignada; vigente, porque condujo esa salida |
| Turno y límite de conducción de C041 | 00:00–23:59; 600 min; 0 min acumulados | **supuesto**: valores por omisión del prototipo |
| Prioridad del servicio | Media (2) | valor por omisión del prototipo; el manifiesto no la consigna |
| Placa, DNI y nombre | SFP-001, 00000041, «Conductor C041 (seudónimo)» | **seudónimos**: identificadores protegidos; no se usan datos personales |

Los datos sustantivos de la salida (fecha, ruta, hora, asientos, pasajeros, unidad y conductor)
son los del manifiesto. Los supuestos no los modifican: completan campos que el manifiesto no
consigna y que el prototipo exige.

## Recorrido y registro

| Paso | Actor y acción (CUS) | Captura | Registro del servidor (UTC) | Bitácora (hora de Lima) |
|---|---|---|---|---|
| 1 | Despacho ingresa (CU-00) | `capturas/00_ingreso.png` | 20:11:15 `POST /api/auth/ingresar → 200` | 15:11:14 `inicio_sesion` |
| 2 | Registra la unidad V001 (CU-02) | `01_formulario_unidad`, `02_unidad_registrada` | 20:11:25 `POST /api/vehiculos → 201` | 15:11:25 `crear_vehiculo` |
| 3 | Registra el conductor C041 (CU-03) | `03_formulario_conductor`, `04_conductor_registrado` | 20:11:41 `POST /api/conductores → 201` | 15:11:41 `crear_conductor` |
| 4 | Autoriza el par V001–C041 como habitual (CU-03) | `05_par_autorizado` | 20:11:52 `PUT /api/vehiculos/1/conductores → 200` | 15:11:52 `asignar_conductores` |
| 5 | Registra la ruta R-02 (CU-04) y su salida de las 04:00 (CU-05) | `06_formulario_ruta`, `07_ruta_y_salida` | 20:12:04 `POST /api/rutas → 201`; 20:12:09 `POST /api/rutas/1/salidas → 201` | 15:12:04 `crear_ruta`; 15:12:09 `crear_salida` |
| 6 | Registra la llegada de V001 a la cola de Tarapoto del 03/10/2026 (CU-02) | `08_formulario_llegada`, `09_cola_tarapoto` | 20:12:25 `POST /api/cola → 201` | 15:12:25 `registrar_llegada` |
| 7 | Registra el servicio 001-029483 (CU-06), con el turno de V001 | `10_formulario_servicio`, `11_servicio_registrado` | 20:12:45 `POST /api/servicios → 201` | 15:12:45 `crear_servicio` |
| 8 | Operaciones genera la programación del 03/10/2026 (CU-07) | `12_propuesta`, `13_gantt` | 20:12:58 `POST /api/programaciones → 201` | 15:12:57 `generar_programacion` |
| 9 | Revisa y aprueba (CU-08, CU-09) | `14_aprobada` | 20:13:04 `POST /api/programaciones/1/aprobar → 200` | 15:13:04 `aprobar_programacion` |

`servidor.log` es el registro completo del servidor; `registro_bd.txt` contiene, extraídas de la
base al terminar, la entrada (unidad, conductor, par, ruta, salida, cola y servicio), la entrada
congelada del núcleo (`snapshot_entrada`, con su huella SHA-256), la salida (`programacion` y
`asignacion`) y la bitácora completa; `prueba_interfaz.log` es la salida de la prueba y
`ejecucion.txt`, la hora de inicio y fin.

## Resultado

| | Manifiesto 001-029483 (despacho real) | Propuesta aprobada del prototipo |
|---|---|---|
| Unidad | V001 | V001 |
| Conductor | C041 | C041 |
| Salida | 4:00 a. m. | 04:00 (término 09:30) |
| Factibilidad | — | Φ = 0 según el validador; sin saltos de cola, reemplazos ni demoras |

El prototipo procesó la salida real de punta a punta y propuso la misma asignación que la empresa
realizó ese día. Con un solo servicio y una sola unidad en la cola, esa coincidencia era la única
asignación factible: el caso demuestra el funcionamiento del sistema con datos reales, no la
calidad del método ni una mejora organizacional, que requieren los registros de RD-01, E-01 y
O-01 (objetivo específico 4).

## Reproducción

```bash
herramientas/caso_real.sh            # requiere docker, dart 3.13.5, flutter 3.47.6, xvfb-run e ImageMagick
```

Una segunda ejecución del mismo script en otra carpeta, el mismo día, dio el mismo resultado
(PASA, 15 capturas, programación aprobada).
