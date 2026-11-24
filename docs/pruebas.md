# Pruebas

| Nivel | Dónde | Qué verifica | Cantidad | Cómo se ejecuta |
|---|---|---|---:|---|
| Unitarias del núcleo | `paquetes/dominio/test/` | ecuación (1) —incluidas las reglas de cola `v ∈ {v0(s), v1(s)}` y de pares `c ∈ {chab(v)} ∪ C_v^R`—, `σ`, `η` y `Δt` con su explicación, JSON canónico y snapshot de la entrada (huella estable y propuesta repetible desde él), F(X) con el ejemplo de la Tabla 21, reparación, AG (reproducibilidad, elitismo, convergencia, óptimo exacto en n = 7), voraz, validador = evaluador en 300 cromosomas, parámetros de las Tablas 11 y 23, contrato JSON, indicadores | 88 | `cd paquetes/dominio && dart test` |
| Aceptación del servidor | `servidor/test/aceptacion/` | los 26 escenarios de la Tabla 33 (HU-01 a HU-11), 13 casos adicionales (duplicados, formatos, rotación de la cookie, reproducibilidad…) y 13 de la cola de despacho y los pares autorizados (`cola_pares_test.dart`: posiciones por orden de llegada, turnos, habitual único, salto de cola y reemplazo explicados, motivo obligatorio en el ajuste, bitácora e indicadores) y 4 de procedencia y versiones (`procedencia_versiones_test.dart`: snapshot con SHA-256 verificado en la base y ejecución repetida desde él, versión nueva por ajuste con la anterior intacta, 409 ante una versión sustituida, dos ajustes y dos aprobaciones simultáneos con un solo registro, tiempo del núcleo aparte), sobre la aplicación completa y MySQL real, con reloj fijo | 56 | `cd servidor && dart test` |
| Contrato HTTP y configuración | `servidor/test/contrato_http_test.dart`, `parametros_sistema_test.dart` | `X-Version-Api`, 426, forma de los errores, CORS, cabeceras de seguridad, validación de `parametros.yaml` | 7 + 3 | idem |
| Unitarias y de widgets del cliente | `cliente/test/` | `ApiCliente` (Bearer, renovación con la cookie, versión, errores), controladores con repositorios en memoria (incluida la cola), formulario HU-06 con servidor simulado y turno de cola por defecto, versión nueva tras un ajuste | 17 | `cd cliente && flutter test` |
| **Ciclo completo (E2E)** | `cliente/integration_test/ciclo_completo_test.dart` | interfaz → servidor → MySQL → interfaz (ver abajo) y generación + aprobación | 1 | `herramientas/e2e.sh` |
| Recorrido de pantallas | `cliente/integration_test/recorrido_pantallas_test.dart` | cada rol ve solo sus módulos y cada pantalla carga sin errores (incluidas la cola de despacho y los conductores autorizados); genera `docs/capturas/` | 1 | `CAPTURAS=docs/capturas herramientas/e2e.sh` |
| Experimento del Anexo E (Python) | `experimentos/sanfelipe/reevaluar_cromosomas.py` y CI «Experimento Python» | huellas de los 14 archivos registrados (protocolo, generador, `core/` y `poc_cap3/` originales); las 1 320 soluciones registradas y los 12 óptimos de n = 7; `datos/` e `incertidumbre_brecha.csv` se regeneran sin cambios | — | ver [`experimentos/README.md`](../experimentos/README.md) |
| Núcleo de referencia en Python (Anexo I) | `pruebas/nucleo/` y `tests/test_core.py` | 100 casos M01 a M12 (modelo, Γ, conducción, aptitud, cota de M, reparación, operadores, parada, reglas de A_s, validador, comparadores y reproducibilidad) y 9 pruebas previas; 300 ejecuciones estocásticas frente a lo registrado | 109 | `bash pruebas/nucleo/ejecutar_pruebas.sh` ([README](../pruebas/nucleo/README.md)) |
| Prueba de humo del núcleo con MySQL (sección 5.6.8) | `pruebas/humo/prueba_humo.py` | base de datos → núcleo → base de datos en 12 pasos (P01 a P12) con MySQL 8.0.46 efímero | 12 pasos | `bash scripts/construir_y_probar.sh` ([manual](MANUAL_COMPILACION.md)) |

## Prueba de ciclo completo (Sesión 7)

Ejecuta la aplicación de **escritorio** real (Linux, con `xvfb-run` si no hay
pantalla) contra el servidor y la base de datos de `docker compose`. Un
`ClienteGrabador` envuelve el cliente HTTP real para observar las solicitudes
sin alterarlas y una conexión directa a MySQL comprueba lo guardado.

| Paso | Verificación |
|---|---|
| 1. El usuario `jdespacho` ingresa y abre «Nuevo servicio» | la navegación muestra solo sus módulos |
| 2. Completa código, ruta R-01 (Soritor–Moyobamba), hora 11:00, prioridad alta y 4 asientos y pulsa «Guardar» | el formulario propone el turno de la unidad que corresponde en la cola: el primero libre que llegó antes de las 11:00 (o «Sin turno de cola» si la base de demostración ya no tiene) |
| 3. Mientras la respuesta está retenida | **el botón «Guardar» está desactivado** (`onPressed == null`) y un segundo toque **no envía otra solicitud** |
| 4. Payload enviado | `{"codigo", "fecha": mañana, "rutaId": id de R-01, "horaSolicitada": 660, "prioridad": 3, "capacidadRequerida": 4, "entradaColaId": turno propuesto}` con los tipos del contrato |
| 5. Respuesta | el cliente intercepta **HTTP 201** y el cuerpo es un `ServicioProgramado` pendiente |
| 6. Base de datos | `SELECT` en `servicio`: misma fecha, hora, prioridad, asientos, turno de cola, estado `pendiente` y `creado_por = jdespacho` |
| 7. Interfaz | el diálogo se cierra y la fila aparece **sin volver a pedir la lista** (no hay otro `GET /api/servicios`) ni recargar la página |
| 8. `operaciones` genera la programación | 201, `phiValidador = 0`; el nuevo servicio queda asignado entre las 11:00 y las 12:00 (`H_s`) con `Δt` = salida − 11:00, con la unidad en turno o la siguiente y `σ` coherente con ella |
| 9. Aprueba | estado `aprobada` en `programacion`, servicio `programado` y evento `aprobar_programacion` en la bitácora |

La misma propiedad (botón desactivado, un solo POST, 201 y actualización
reactiva) se prueba también sin servidor en
`cliente/test/registro_servicio_widget_test.dart`, que corre en segundos.

## Evidencia en GitHub Actions

Cada push ejecuta, además de las pruebas de cada paquete, el trabajo
**«Ciclo completo (E2E, escritorio Linux)»**: levanta `docker compose`, corre
`herramientas/e2e.sh` bajo Xvfb y publica el artefacto `evidencia-e2e` con la
salida completa (encabezada por el commit y la fecha UTC) y las capturas de
cada pantalla. El artefacto `cobertura-dominio` guarda el informe LCOV del
núcleo. Así la evidencia E2E corresponde siempre al mismo commit que se
revisa. El trabajo **«Experimento Python»** repite en cada push las
comprobaciones del paquete del Anexo E con Python 3.11 y las versiones
registradas de NumPy, PyGAD y PuLP.

## Ejecución completa

```sh
docker compose up -d --build                       # entorno
(cd paquetes/dominio && dart test)                 # 88
herramientas/cobertura.sh                          # cobertura del núcleo ≥ 80 %
(cd servidor && dart test)                         # 66, usa <DB_NAME>_pruebas
(cd cliente && flutter test)                       # 17
herramientas/e2e.sh                                # 2 pruebas de integración
```

Las pruebas del servidor leen `PRUEBAS_DB_*` (o `DB_PASSWORD`) y **borran y
recrean las tablas** de la base de pruebas; por seguridad se niegan a correr
si su nombre no termina en `_pruebas`.

## Resultado de la versión 1.2.0

Todas las pruebas pasan (88 + 66 + 17 + 2 = **173**). La cobertura de líneas del núcleo (`lib/src/optimizacion`) es **97,9 %** (RNF-07 exige ≥ 80 %); la del paquete completo, 79,0 %, porque parte de los `toJson`/`fromJson` de los modelos se prueba desde el servidor y el cliente. En la 1.1.0 eran 82 + 62 + 16 + 2 = 162.

En la versión 1.0.0 (sin cola ni pares) eran 61 + 49 + 14 + 2 = 126 pruebas y
la cobertura del núcleo, 96,3 %. En esa versión se verificó además con
Playwright el cliente web en Chromium contra `docker compose` (no se repitió
en la 1.1.0, que no cambia la sesión ni la autenticación): la cookie `refresco` es
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
