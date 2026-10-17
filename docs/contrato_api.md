# Contrato de la API REST (versión 1.2.0)

El contrato vive en código, en `paquetes/dominio/lib/src/contrato/` y
`paquetes/dominio/lib/src/modelos/`: el servidor y el cliente importan **los
mismos** modelos con sus `toJson`/`fromJson`, de modo que no pueden discrepar
sobre la forma de los datos. Este documento lo resume.

## Convenciones

| Aspecto | Regla |
|---|---|
| Base | `/api` (en Docker, el cliente web la usa en el mismo origen a través de nginx) |
| Formato | JSON UTF-8 (`application/json; charset=utf-8`); CSV solo en la exportación |
| Horas | minutos desde la medianoche, enteros en `[0, 1440)` (`450` = 07:30), igual que en el modelo matemático |
| Fechas | `AAAA-MM-DD`; marcas de tiempo ISO-8601 en la hora local de la empresa (UTC−5) |
| Identificadores | enteros generados por MySQL; los códigos (`V-07`, `S-115`) son únicos y se normalizan a mayúsculas |
| Paginación | `?pagina=1&tamano=50` (máx. 200) → `{elementos, total, pagina, tamano}` |
| Tipos | estrictos: `"3"` no es un entero válido (HTTP 400 con el campo señalado) |

## Versionado y compatibilidad cliente–servidor

* `versionApi = '1.2.0'` (`contrato/version.dart`) sigue las etiquetas del
  repositorio (`v1.2.0`). La 1.1.0 agregó la cola de despacho, los pares
  autorizados y las salidas `σ`, `η` y `Δt` (sección 3.1.2 de la tesis); la
  1.2.0, la procedencia y las versiones de cada propuesta (sección 5.5,
  CU-09 y CU-12). Un cliente de otra versión MENOR recibe 426.
* Toda respuesta lleva **`X-Version-Api`**; el cliente la compara con la suya
  y, si no coincide en MAYOR.MENOR, muestra «actualice la aplicación».
* El cliente envía **`X-Version-Cliente`**; si es incompatible el servidor
  responde **426** antes de procesar la solicitud.
* `GET /api/version` → `{"versionApi": "1.2.0", "versionServidor": "1.2.0"}`.

## Autenticación

| Paso | Detalle |
|---|---|
| Ingreso | `POST /api/auth/ingresar {nombreUsuario, contrasena}` → `200 {tokenAcceso, expiraEnSegundos, usuario}` |
| Token de acceso | JWT HS256 de 15 min, enviado como `Authorization: Bearer …`; el cliente lo guarda solo en memoria |
| Token de actualización | 32 bytes aleatorios en la cookie `refresco` (`HttpOnly; SameSite=Strict; Secure; Path=/api/auth`); en MySQL se guarda su SHA-256 |
| Renovación | `POST /api/auth/refrescar` (con la cookie) → nuevo JWT y nueva cookie; la anterior queda revocada (rotación) |
| Cierre | `POST /api/auth/salir` → 204 y cookie vencida |
| Bloqueo | 5 contraseñas incorrectas → 423 durante 15 min y evento `bloqueo_cuenta` en la bitácora |

## Errores

```json
{ "error": { "codigo": "regla_negocio", "mensaje": "La hora no es una salida autorizada de la ruta R-03",
             "campos": { "horaSolicitada": "La hora no es una salida autorizada de la ruta R-03" } } }
```

| HTTP | `codigo` | Cuándo |
|---|---|---|
| 400 | `solicitud_invalida` | cuerpo que no es JSON, campo faltante o con otro tipo |
| 401 | `no_autenticado` | sin token, token inválido o vencido, credenciales incorrectas |
| 403 | `prohibido` | el rol no tiene acceso al módulo (matriz `Permisos`) |
| 404 | `no_encontrado` | recurso inexistente (`Servicio no encontrado`) |
| 409 | `conflicto` | dato duplicado (placa, DNI, código) o aprobación con cruces |
| 422 | `regla_negocio` | regla de negocio incumplida (licencia vencida, hora no autorizada…) |
| 423 | `bloqueado` | cuenta bloqueada temporalmente |
| 426 | `version_incompatible` | cliente con otra versión MAYOR.MENOR |
| 500 | `interno` | error inesperado (el detalle solo queda en el registro del servidor) |

## Recursos

L = lectura, E = escritura; D = despacho, O = operaciones, A = administrador.

| Método y ruta | Rol | Respuesta | HU |
|---|---|---|---|
| `POST /api/auth/ingresar` | público | 200 `SesionIniciada` + cookie | HU-01 |
| `POST /api/auth/refrescar` | cookie | 200 `SesionIniciada` + cookie | HU-01 |
| `POST /api/auth/salir` | cookie | 204 | HU-01 |
| `GET /api/version`, `GET /api/salud` | público | 200 | — |
| `GET /api/usuarios` · `POST /api/usuarios` | A | 200 `Pagina<Usuario>` · 201 `Usuario` | HU-01 |
| `GET /api/vehiculos[?estado=operativo]` · `GET /api/vehiculos/{id}` | L: D, O | 200 | HU-02 |
| `POST /api/vehiculos` · `PUT /api/vehiculos/{id}` | E: D | 201 · 200 `Vehiculo` | HU-02 |
| `GET /api/pares` · `GET /api/vehiculos/{id}/conductores` | L: D, O | 200 lista de `ParAutorizado` · `ConductoresAutorizados` | HU-02, HU-03 |
| `PUT /api/vehiculos/{id}/conductores {conductorHabitualId?, reemplazos}` | E: D | 200 `ConductoresAutorizados` · 409 si el habitual ya lo es de otra unidad · 422 | HU-02, HU-03 |
| `GET /api/conductores` · `GET /api/conductores/{id}` | L: D, O | 200 | HU-03 |
| `POST /api/conductores` · `PUT /api/conductores/{id}` | E: D | 201 · 200 `Conductor` | HU-03 |
| `PUT /api/conductores/{id}/disponibilidad {disponible}` | E: D | 200 · 422 «Licencia vencida» | HU-03 |
| `GET /api/rutas` · `GET /api/rutas/{id}` | L: D, O | 200 `Ruta` (con `vehiculosCompatibles`) | HU-04 |
| `POST /api/rutas` · `PUT /api/rutas/{id}` | E: D | 201 · 200 | HU-04 |
| `GET /api/rutas/{id}/salidas` · `POST /api/rutas/{id}/salidas {hora, duracionMin?}` | L/E: D | 200 · 201 `SalidaAutorizada` | HU-05 |
| `DELETE /api/salidas/{id}` | E: D | 204 · 409 si tiene servicios | HU-05 |
| `GET /api/cola?fecha=&rutaId=` | L: D, O | 200 lista de `EntradaCola` por orden de llegada · 400 sin fecha | HU-02, HU-06 |
| `POST /api/cola {rutaId, fecha, vehiculoId, llegada}` | E: D | 201 `EntradaCola` con la posición siguiente · 409 si la unidad ya espera turno · 422 | HU-02, HU-06 |
| `POST /api/cola/{id}/retirar` | E: D | 200 `EntradaCola` inactiva | HU-02 |
| `GET /api/servicios?fecha=&estado=` · `GET /api/servicios/{id}` | L: D, O | 200 `Pagina<ServicioProgramado>` (con `codigoVehiculoCola` y `posicionCola`) | HU-06 |
| `POST /api/servicios` · `PUT /api/servicios/{id}` (`entradaColaId?`) | E: D | 201 · 200 · 409 turno ya tomado · 422 turno de otra cola, retirado o posterior a la salida | HU-06 |
| `POST /api/servicios/{id}/cancelar` | E: D | 200 | HU-06 |
| `POST /api/programaciones {fecha}` | E: O | 201 `Programacion` · 422 sin pendientes | HU-07 |
| `GET /api/programaciones?fecha=` | L: O | 200 lista de resúmenes (sin asignaciones) | HU-08 |
| `GET /api/programaciones/{id}` | L: O | 200 `Programacion` con asignaciones e historial (la curva de su ejecución), `version`, `ejecucionId`, `versionAnteriorId`, `huellaEntrada`, `versionAlgoritmo`, `tiempoMs` y `tiempoNucleoMs` | HU-08 |
| `GET /api/programaciones/{id}/entrada` | L: O | 200 `SnapshotEntrada` `{id, fecha, sha256, contenido, creadoEn}`: SHA-256 del JSON canónico de `contenido` = `sha256` | HU-07 |
| `PUT /api/programaciones/{id}/asignaciones/{servicioId} {vehiculoId, conductorId, salida, justificacion?}` | E: O | 200 con la **versión nueva** (otro `id`; la ajustada queda `sustituida`), con los cruces marcados como `conflicto` · 409 si la versión ya fue sustituida · 422 si no es admisible o si salta la cola, reemplaza al habitual o demora la salida sin `justificacion` | HU-09 |
| `POST /api/programaciones/{id}/aprobar` | E: O | 200 · 409 con cruces sin resolver o si la versión fue sustituida · 422 si ya no es una propuesta (por ejemplo, otra solicitud la aprobó) | HU-09 |
| `GET /api/incidencias?desde=&hasta=` · `POST /api/incidencias` | L/E: D (L: O) | 200 · 201 `Incidencia` · 404 servicio | HU-10 |
| `GET /api/reportes/indicadores?desde=&hasta=` | O | 200 `ReporteIndicadores` (PIO…PAV, los operativos `reemplazos`, `saltosCola`, `salidasDemoradas`, `minutosDemora`, `retrasoAcumuladoMin`, `tiempoMuertoMin`, y los tiempos medios de la solicitud y del núcleo sobre las ejecuciones) | HU-11 |
| `GET /api/reportes/indicadores.csv?desde=&hasta=` | O | 200 `text/csv` (adjunto) | HU-11 |
| `GET /api/bitacora?pagina=&accion=&entidad=&entidadId=` | A | 200 `Pagina<EntradaBitacora>` | RNF-06 |
| `GET /api/parametros` | A | 200 parámetros efectivos | RNF-07 |

### Ejemplo: registro de un servicio (HU-06)

```http
POST /api/servicios HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIs…
X-Version-Cliente: 1.2.0
Content-Type: application/json

{"codigo":"S-115","fecha":"2026-11-12","rutaId":1,"horaSolicitada":660,"prioridad":3,"capacidadRequerida":10,
 "entradaColaId":8}
```

```http
HTTP/1.1 201 Created
X-Version-Api: 1.2.0

{"id":115,"codigo":"S-115","fecha":"2026-11-12","rutaId":1,"horaSolicitada":660,"prioridad":3,
 "capacidadRequerida":10,"estado":"pendiente","entradaColaId":8,"codigoRuta":"R-01",
 "codigoVehiculoCola":"V-04","posicionCola":8}
```

### Ejemplo: llegada a la cola

```http
POST /api/cola HTTP/1.1

{"rutaId":1,"fecha":"2026-11-12","vehiculoId":4,"llegada":540}
```

```json
{"id":8,"rutaId":1,"fecha":"2026-11-12","vehiculoId":4,"posicion":8,"llegada":540,"activa":true,
 "codigoVehiculo":"V-04","servicioId":null}
```

### Ejemplo: programación generada (HU-07)

```json
{
  "id": 1, "fecha": "2026-11-12", "estado": "propuesta", "metodo": "algoritmo_genetico",
  "aptitud": -0.4206, "phi": 0, "phiValidador": 0,
  "componentes": {"conflictosVehiculo": 0, "conflictosConductor": 0, "conductoresExcedidos": 0,
                  "excesoMin": 0, "retrasoMin": 0, "reprogramados": 0, "tiempoMuertoMin": 395,
                  "desviacionCarga": 21.9, "perdida": 0.4206},
  "generaciones": 59, "tiempoMs": 142, "semilla": 1,
  "version": 1, "ejecucionId": 1, "versionAnteriorId": null, "tiempoNucleoMs": 35,
  "versionAlgoritmo": "algoritmo_genetico@1.2.0",
  "huellaEntrada": "6c1f…(64 hexadecimales)",
  "asignaciones": [
    {"servicioId": 5, "codigoServicio": "S-0005", "codigoRuta": "R-02", "prioridad": 2,
     "vehiculoId": 6, "codigoVehiculo": "V-06", "conductorId": 6, "codigoConductor": "C-06",
     "salida": 360, "fin": 690, "estado": "asignado", "motivo": null, "ajustada": false,
     "saltoCola": true, "reemplazo": false, "demoraMin": 0,
     "codigoVehiculoCola": "V-10", "codigoConductorHabitual": "C-06",
     "justificacion": "Propuesta del sistema — salto de cola: la unidad que corresponde (V-10) no está disponible, dejó la cola o no tiene un conductor autorizado para el servicio"}
  ],
  "historial": [{"generacion": 0, "mejor": -0.61, "promedio": -2400000.5}]
}
```

Las pruebas de contrato están en `servidor/test/contrato_http_test.dart`
(versión, cabeceras, forma de los errores, CORS) y en
`paquetes/dominio/test/contrato_test.dart` (ida y vuelta por JSON, tipos
estrictos, compatibilidad de versiones).
