# Contrato de la API REST (versión 1.0.0)

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

* `versionApi = '1.0.0'` (`contrato/version.dart`) sigue las etiquetas del
  repositorio (`v1.0.0`).
* Toda respuesta lleva **`X-Version-Api`**; el cliente la compara con la suya
  y, si no coincide en MAYOR.MENOR, muestra «actualice la aplicación».
* El cliente envía **`X-Version-Cliente`**; si es incompatible el servidor
  responde **426** antes de procesar la solicitud.
* `GET /api/version` → `{"versionApi": "1.0.0", "versionServidor": "1.0.0"}`.

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
| `GET /api/conductores` · `GET /api/conductores/{id}` | L: D, O | 200 | HU-03 |
| `POST /api/conductores` · `PUT /api/conductores/{id}` | E: D | 201 · 200 `Conductor` | HU-03 |
| `PUT /api/conductores/{id}/disponibilidad {disponible}` | E: D | 200 · 422 «Licencia vencida» | HU-03 |
| `GET /api/rutas` · `GET /api/rutas/{id}` | L: D, O | 200 `Ruta` (con `vehiculosCompatibles`) | HU-04 |
| `POST /api/rutas` · `PUT /api/rutas/{id}` | E: D | 201 · 200 | HU-04 |
| `GET /api/rutas/{id}/salidas` · `POST /api/rutas/{id}/salidas {hora, duracionMin?}` | L/E: D | 200 · 201 `SalidaAutorizada` | HU-05 |
| `DELETE /api/salidas/{id}` | E: D | 204 · 409 si tiene servicios | HU-05 |
| `GET /api/servicios?fecha=&estado=` · `GET /api/servicios/{id}` | L: D, O | 200 `Pagina<ServicioProgramado>` | HU-06 |
| `POST /api/servicios` · `PUT /api/servicios/{id}` | E: D | 201 · 200 | HU-06 |
| `POST /api/servicios/{id}/cancelar` | E: D | 200 | HU-06 |
| `POST /api/programaciones {fecha}` | E: O | 201 `Programacion` · 422 sin pendientes | HU-07 |
| `GET /api/programaciones?fecha=` | L: O | 200 lista de resúmenes (sin asignaciones) | HU-08 |
| `GET /api/programaciones/{id}` | L: O | 200 `Programacion` con asignaciones e historial | HU-08 |
| `PUT /api/programaciones/{id}/asignaciones/{servicioId} {vehiculoId, conductorId, salida}` | E: O | 200 (cruces marcados como `conflicto`) · 422 si no es admisible | HU-09 |
| `POST /api/programaciones/{id}/aprobar` | E: O | 200 · 409 con cruces sin resolver | HU-09 |
| `GET /api/incidencias?desde=&hasta=` · `POST /api/incidencias` | L/E: D (L: O) | 200 · 201 `Incidencia` · 404 servicio | HU-10 |
| `GET /api/reportes/indicadores?desde=&hasta=` | O | 200 `ReporteIndicadores` | HU-11 |
| `GET /api/reportes/indicadores.csv?desde=&hasta=` | O | 200 `text/csv` (adjunto) | HU-11 |
| `GET /api/bitacora?pagina=&accion=&entidad=&entidadId=` | A | 200 `Pagina<EntradaBitacora>` | RNF-06 |
| `GET /api/parametros` | A | 200 parámetros efectivos | RNF-07 |

### Ejemplo: registro de un servicio (HU-06)

```http
POST /api/servicios HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIs…
X-Version-Cliente: 1.0.0
Content-Type: application/json

{"codigo":"S-115","fecha":"2026-11-12","rutaId":3,"horaSolicitada":450,"prioridad":3,"capacidadRequerida":10}
```

```http
HTTP/1.1 201 Created
X-Version-Api: 1.0.0

{"id":115,"codigo":"S-115","fecha":"2026-11-12","rutaId":3,"horaSolicitada":450,"prioridad":3,
 "capacidadRequerida":10,"estado":"pendiente","codigoRuta":"R-03"}
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
  "asignaciones": [
    {"servicioId": 2, "codigoServicio": "S-0002", "codigoRuta": "R-02", "prioridad": 3,
     "vehiculoId": 2, "codigoVehiculo": "V-02", "conductorId": 3, "codigoConductor": "C-03",
     "salida": 300, "fin": 480, "estado": "asignado", "motivo": null, "ajustada": false}
  ],
  "historial": [{"generacion": 0, "mejor": -0.61, "promedio": -2400000.5}]
}
```

Las pruebas de contrato están en `servidor/test/contrato_http_test.dart`
(versión, cabeceras, forma de los errores, CORS) y en
`paquetes/dominio/test/contrato_test.dart` (ida y vuelta por JSON, tipos
estrictos, compatibilidad de versiones).
