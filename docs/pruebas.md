# Pruebas

| Nivel | Dónde | Qué verifica | Cantidad | Cómo se ejecuta |
|---|---|---|---:|---|
| Unitarias del núcleo | `paquetes/dominio/test/` | ecuación (1), F(X) con el ejemplo de la Tabla 21, reparación, AG (reproducibilidad, elitismo, convergencia, óptimo exacto en n = 7), voraz, validador = evaluador en 300 cromosomas, contrato JSON, indicadores | 53 | `cd paquetes/dominio && dart test` |
| Aceptación del servidor | `servidor/test/aceptacion/` | los 26 escenarios de la Tabla 33 (HU-01 a HU-11) y 13 casos adicionales (duplicados, formatos, rotación de la cookie, reproducibilidad…), sobre la aplicación completa y MySQL real, con reloj fijo | 39 | `cd servidor && dart test` |
| Contrato HTTP y configuración | `servidor/test/contrato_http_test.dart`, `parametros_sistema_test.dart` | `X-Version-Api`, 426, forma de los errores, CORS, cabeceras de seguridad, validación de `parametros.yaml` | 7 + 3 | idem |
| Unitarias y de widgets del cliente | `cliente/test/` | `ApiCliente` (Bearer, renovación con la cookie, versión, errores), controladores con repositorios en memoria, formulario HU-06 con servidor simulado | 14 | `cd cliente && flutter test` |
| **Ciclo completo (E2E)** | `cliente/integration_test/ciclo_completo_test.dart` | interfaz → servidor → MySQL → interfaz (ver abajo) y generación + aprobación | 1 | `herramientas/e2e.sh` |
| Recorrido de pantallas | `cliente/integration_test/recorrido_pantallas_test.dart` | cada rol ve solo sus módulos y cada pantalla carga sin errores; genera `docs/capturas/` | 1 | `CAPTURAS=docs/capturas herramientas/e2e.sh` |

## Prueba de ciclo completo (Sesión 7)

Ejecuta la aplicación de **escritorio** real (Linux, con `xvfb-run` si no hay
pantalla) contra el servidor y la base de datos de `docker compose`. Un
`ClienteGrabador` envuelve el cliente HTTP real para observar las solicitudes
sin alterarlas y una conexión directa a MySQL comprueba lo guardado.

| Paso | Verificación |
|---|---|
| 1. El usuario `jdespacho` ingresa y abre «Nuevo servicio» | la navegación muestra solo sus módulos |
| 2. Completa código, ruta R-03, hora 07:30, prioridad alta y 4 asientos y pulsa «Guardar» | — |
| 3. Mientras la respuesta está retenida | **el botón «Guardar» está desactivado** (`onPressed == null`) y un segundo toque **no envía otra solicitud** |
| 4. Payload enviado | `{"codigo", "fecha": mañana, "rutaId": id de R-03, "horaSolicitada": 450, "prioridad": 3, "capacidadRequerida": 4}` con los tipos del contrato |
| 5. Respuesta | el cliente intercepta **HTTP 201** y el cuerpo es un `ServicioProgramado` pendiente |
| 6. Base de datos | `SELECT` en `servicio`: misma fecha, hora, prioridad, asientos, estado `pendiente` y `creado_por = jdespacho` |
| 7. Interfaz | el diálogo se cierra y la fila aparece **sin volver a pedir la lista** (no hay otro `GET /api/servicios`) ni recargar la página |
| 8. `operaciones` genera la programación | 201, `phiValidador = 0`, el nuevo servicio queda asignado a las 07:30 |
| 9. Aprueba | estado `aprobada` en `programacion`, servicio `programado` y evento `aprobar_programacion` en la bitácora |

La misma propiedad (botón desactivado, un solo POST, 201 y actualización
reactiva) se prueba también sin servidor en
`cliente/test/registro_servicio_widget_test.dart`, que corre en segundos.

## Ejecución completa

```sh
docker compose up -d --build                       # entorno
(cd paquetes/dominio && dart test)                 # 53
(cd servidor && dart test)                         # 49, usa <DB_NAME>_pruebas
(cd cliente && flutter test)                       # 14
herramientas/e2e.sh                                # 2 pruebas de integración
```

Las pruebas del servidor leen `PRUEBAS_DB_*` (o `DB_PASSWORD`) y **borran y
recrean las tablas** de la base de pruebas; por seguridad se niegan a correr
si su nombre no termina en `_pruebas`.

## Resultado de la versión 1.0.0

Todas las pruebas pasan (53 + 49 + 14 + 2 = **118**). Además se verificó con Playwright
el cliente web en Chromium contra `docker compose`: la cookie `refresco` es
`HttpOnly`, `SameSite=Strict` y `Secure`, `document.cookie` no la expone,
recargar la página reanuda la sesión sin pedir la contraseña y la aplicación
no hace solicitudes a dominios externos.

## Definición de terminado (tesis, sección 3.8)

* Código en el repositorio con commits semánticos y etiquetas de versión.
* Pruebas unitarias del núcleo y de aceptación de cada historia sin errores.
* Toda programación generada en las pruebas tiene Φ = 0 según el validador
  independiente, salvo los servicios sin alternativas (incidencias).
* RNF verificados: RNF-01 (Φ = 0), RNF-02 (tiempos de `formalizacion_algoritmo.md` §6),
  RNF-03 (pruebas de contrato), RNF-05 (`herramientas/respaldo.sh`),
  RNF-06 (pruebas HU-01 y HU-09), RNF-07 (parámetros en YAML),
  RNF-08 (`docker compose up --build`).
