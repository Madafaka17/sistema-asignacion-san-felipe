# Wireframes por caso de uso y su implementación

La tesis define las historias de usuario y sus criterios de aceptación
(Tabla 33) pero no incluye prototipos de pantalla, así que se diseñaron los
wireframes de baja fidelidad de esta página a partir de esos criterios. Cada
elemento del wireframe tiene su widget en el cliente Flutter; las claves
(`Key('…')`) son las que usan las pruebas automatizadas, de modo que la
correspondencia wireframe → código se verifica en cada ejecución de
`cliente/integration_test/recorrido_pantallas_test.dart`, que además genera
las capturas de `docs/capturas/` contra el servidor real.

Estructura común (todas las pantallas autenticadas, `MarcoPrincipal`):

```text
┌────────────────────────────────────────────────────────────────────────┐
│ <Módulo>                                 <usuario> · <rol>   [Salir]   │  AppBar · boton_salir
├──────────────┬─────────────────────────────────────────────────────────┤
│ ▸ módulo 1   │ <Título>                         [acciones principales] │  EncabezadoPantalla
│   módulo 2   │ <descripción / contador>                                │
│   …          │ [!] mensaje de error (si lo hay)                        │  BannerError · mensaje_error
│ (solo los    │ ┌─────────────────────────────────────────────────────┐ │
│  del rol)    │ │ tabla / contenido                                   │ │  TablaDatos
└──────────────┴─────────────────────────────────────────────────────────┘
  NavigationRail (≥ 760 px) o menú lateral (pantallas angostas) · modulo_<nombre>
```

---

## W-01 · Ingreso (HU-01)

```text
            ┌────────────────────────────────┐
            │            [bus]               │
            │     Transportes San Felipe     │
            │     Asignación de recursos     │
            │  (aviso: «La sesión expiró…»)  │  aviso_sesion
            │  [ Usuario                   ] │  campo_usuario
            │  [ Contraseña           (ojo)] │  campo_contrasena
            │  [!] Usuario o contraseña…     │  mensaje_error
            │  [        Ingresar           ] │  boton_ingresar (BotonAsincrono)
            └────────────────────────────────┘
```

Código: `cliente/lib/vistas/pantallas/pantalla_ingreso.dart` ·
controlador `SesionControlador.ingresar` ·
captura [`00_ingreso.png`](capturas/00_ingreso.png).
Criterios: el despacho ve solo registro e incidencias (`Permisos.modulosNavegacion`);
la quinta contraseña incorrecta muestra «Cuenta bloqueada temporalmente».

## W-01b · Usuarios (HU-01, administrador)

```text
│ Usuarios                                  [+ Nuevo usuario] │  boton_nuevo_usuario
│ Usuario │ Nombre │ Rol │ Activo                              │
│ Diálogo: Usuario · Nombre completo · Rol ▾ · Contraseña     │
```

Código: `pantalla_administracion.dart` (`PantallaUsuarios`) ·
captura [`administrador_usuarios.png`](capturas/administrador_usuarios.png).

## W-02 · Vehículos (HU-02)

```text
│ Flota                                      [+ Nuevo vehículo] │  boton_nuevo_vehiculo
│ 9 de 10 unidades operativas                                   │
│ Código │ Placa │ Categoría │ Asientos │ Estado │ Habitual · reemplazos │ [✎][🪪] │  vehiculo_<código>, conductores_<código>
│ Diálogo: Código · Placa (ABC-123) · Asientos · Categoría ▾ ·  │  campo_placa, campo_capacidad
│          Estado ▾ (operativo / mantenimiento / inactivo)      │  campo_estado_vehiculo
│          [!] «La placa ya está registrada»       [Guardar]    │  boton_guardar_vehiculo
│ Diálogo «Conductores autorizados de V-01» (sección 3.1.2):    │
│   Conductor habitual ▾ (o «Sin conductor habitual»)           │  campo_conductor_habitual
│   Reemplazos autorizados: (C-02) (C-09✓) (C-12) …             │  reemplazo_<código>
│   [!] «C-01 ya es conductor habitual de V-05»    [Guardar]    │  boton_guardar_conductores
```

Código: `pantalla_vehiculos.dart` · `VehiculosControlador.asignarConductores` ·
capturas [`despacho_vehiculos.png`](capturas/despacho_vehiculos.png) y
[`despacho_conductores_autorizados.png`](capturas/despacho_conductores_autorizados.png).

## W-03 · Conductores (HU-03)

```text
│ Conductores                               [+ Nuevo conductor] │
│ 5 habilitados                                                 │
│ Código │ Nombre │ Licencia │ Vence │ Turno │ Acum./límite │ Disponible (◉) │
│   fila resaltada si la licencia está vencida                  │
│ Diálogo: Código · DNI · Nombres · Apellidos · Licencia ▾ ·    │
│          Vencimiento · Inicio/Fin de turno · H_c0 · H_cmáx    │
```

Código: `pantalla_conductores.dart` · `ConductoresControlador.cambiarDisponibilidad`
(muestra «Licencia vencida» si el servidor responde 422) ·
captura [`despacho_conductores.png`](capturas/despacho_conductores.png).

## W-04/05 · Rutas y salidas autorizadas (HU-04, HU-05)

```text
│ Rutas autorizadas                               [+ Nueva ruta] │
│ ┌──────────────────────────────────┬─────────────────────────┐ │
│ │ Código │ Origen–destino │ Redondo │ Ida │ Salidas autorizadas │ │
│ │ R-01 ◂ │ Soritor–Moyob. │ 90 min  │ 30  │ R-01 · término +90  │ │
│ │ R-02   │ Soritor–Tarap. │ 330 min │ 150 │ [HH:MM] [Agregar]   │ │  campo_hora_salida, boton_agregar_salida
│ │        │                │         │     │ (06:00 ×) (07:30 ×) │ │  salida_<HH:MM>
│ └────────────────────────────────────────┴─────────────────────┘ │
│ Diálogo de ruta: Código · Origen · Destino · Viaje redondo (>0) │  campo_duracion_ruta
│   · Ida declarada (opcional) · compatibles (chips) · Activa     │  campo_ida_ruta
```

Código: `pantalla_rutas.dart` (maestro–detalle) · `RutasControlador` ·
captura [`despacho_rutas.png`](capturas/despacho_rutas.png).

## W-06 · Servicios del turno (HU-06)

```text
│ Servicios del turno         [Turno: 12/11/2026] [+ Nuevo servicio] │  boton_nuevo_servicio
│ 12 pendientes                                                     │
│ Código │ Ruta │ Hora │ Turno en la cola │ Prioridad │ Asientos │ Estado │ [✎][✕] │  servicio_<código>
│ Diálogo «Nuevo servicio · 12/11/2026»:                            │
│   Código [S-115]            campo_codigo_servicio                 │
│   Ruta ▾ (obligatoria)      campo_ruta_servicio                   │
│   Hora ▾ (solo salidas autorizadas de la ruta)  campo_hora_servicio_<ruta> │
│   Turno en la cola ▾ [Posición 8 · V-04 (llegó 09:00)]            │  campo_cola_servicio_<ruta>_<hora>
│     por defecto, el primer turno libre que llegó antes de la salida (v0(s)); │
│     «Sin turno de cola» si no lo hay                              │
│   Prioridad ▾ Alta/Media/Baja   Asientos [10]                     │
│                         [Cancelar] [⟳ Guardar]  boton_guardar_servicio │
```

Código: `pantalla_servicios.dart` · `ServiciosControlador.guardar` ·
capturas [`01_servicios.png`](capturas/01_servicios.png),
[`02_formulario_servicio.png`](capturas/02_formulario_servicio.png),
[`03_guardando.png`](capturas/03_guardando.png) (botón desactivado durante el
envío) y [`04_servicio_registrado.png`](capturas/04_servicio_registrado.png).

## W-12 · Cola de despacho (sección 3.1.2)

```text
│ Cola de despacho                 [Turno: 12/11/2026] [+ Registrar llegada] │  boton_registrar_llegada
│ R-01 · Soritor – Moyobamba: 2 unidades esperan turno                    │
│ (R-01 · Moyobamba ✓) (R-02 · Tarapoto)                                  │  cola_ruta_<código>
│ Posición │ Unidad │ Llegada │ Turno                    │ [⊖]           │  tabla_cola, entrada_<π>, retirar_<π>
│ 1        │ V-01   │ 05:20   │ Servicio S-0001          │ [⊖]           │
│ 8        │ V-04   │ 09:00   │ Espera turno             │ [⊖]           │
│ 2        │ V-10   │ 04:45   │ Dejó la cola (resaltada) │               │
│ Diálogo «Llegada a la cola de R-01»: Unidad ▾ (operativas y compatibles) │  campo_unidad_llegada
│   · Hora de llegada [HH:MM]; recibe la posición siguiente a la última   │  campo_hora_llegada, boton_guardar_llegada
│   [!] «La unidad V-01 ya espera turno en la posición 1 de la cola de R-01» │
```

Código: `pantalla_cola.dart` · `ColaControlador` ·
captura [`despacho_cola.png`](capturas/despacho_cola.png).

## W-07/08/09 · Programación del turno (HU-07, HU-08, HU-09)

```text
│ Programación del turno   [Turno ▾] [✦ Generar programación] [✓ Aprobar] │  boton_generar, boton_aprobar
│ Propuesta generada: 12 servicios asignados                              │  mensaje_programacion
│ [!] Hay cruces sin resolver (Φ = 2): ajuste las asignaciones marcadas   │  aviso_cruces
│ Ejecuciones: (#3 v2 · Propuesta · 08:06) (#3 · Sustituida por un ajuste · 08:05) (#1 · Aprobada · 08:00) │
│ ┌Estado: ejecución #3 · versión 2┐┌Asignados┐┌Φ validador┐┌Saltos·reemplazos┐┌F(X)┐┌Tm┐┌D┐ │  kpi_asignados, kpi_phi, kpi_excepciones
│ ┌AG: núcleo 0,03 s · solicitud 0,05 s┐┌Procedencia: 6c1f2a9b04de… · algoritmo_genetico@1.2.0 · semilla 1┐ │  kpi_procedencia
│ [Asignaciones] [Gantt] [Convergencia]                                    │
│ Servicio│Ruta│Vehíc.│Cond.│Salida│Término│Excepciones                  │Estado│[✎] │  asignacion_<código>, ajustar_<código>
│ S-108   │R-02│  —   │  —  │  —   │  —    │ —                           │Incidencia: … │  ← incidencias primero
│ S-0005  │R-02│ V-06 │C-06 │06:00 │11:30  │(⇄ Salto de cola, correspondía V-10) │Asignado│[✎] │  excepciones_<código>
│ S-0003  │R-01│ V-02 │C-02 │07:30 │09:00  │(⏱ +60 min)                  │Asignado│[✎] │  (tooltip: justificación)
│ Gantt: una fila por vehículo, barras salida→término (cruces en rojo)    │  gantt_<código>
│ Convergencia: mejor F(X) y F(X) promedio por generación                 │
│ Diálogo de ajuste: Vehículo ▾ · Conductor ▾ · Hora de salida ·           │  boton_guardar_ajuste
│   Motivo del ajuste (obligatorio si salta la cola o reemplaza al habitual) │  campo_justificacion_ajuste
```

Código: `pantalla_programacion.dart`, `diagrama_gantt.dart`,
`grafico_convergencia.dart` · `ProgramacionControlador` ·
capturas [`05_propuesta.png`](capturas/05_propuesta.png),
[`06_gantt.png`](capturas/06_gantt.png),
[`07_convergencia.png`](capturas/07_convergencia.png),
[`operaciones_ajuste.png`](capturas/operaciones_ajuste.png) y
[`08_aprobada.png`](capturas/08_aprobada.png).
«Aprobar» está desactivado mientras el validador reporte Φ > 0 (HU-09, escenario de error).

## W-10 · Incidencias (HU-10)

```text
│ Incidencias                              [+ Registrar incidencia] │  boton_nueva_incidencia
│ Fecha │ Servicio │ Tipo │ Retraso │ Vehículo │ Conductor │ Causa   │
│ Diálogo: Código del servicio · Tipo ▾ · Fecha · Hora ·            │
│          Minutos de retraso (si es retraso) · Causa               │  boton_guardar_incidencia
│          [!] «Servicio no encontrado»                             │
```

Código: `pantalla_incidencias.dart` · `IncidenciasControlador` ·
captura [`despacho_incidencias.png`](capturas/despacho_incidencias.png).

## W-11 · Reporte de indicadores (HU-11)

```text
│ Reporte de indicadores  [Desde] [Hasta] [Generar reporte] [⇩ Exportar CSV] │  boton_generar_reporte, boton_exportar
│ ┌Servicios┐┌PIO┐┌PSR 6.3 %┐┌PSA 4.7 %┐┌PUV┐┌PAV┐┌D(X)┐┌Tiempo medio┐       │  kpi_pio, kpi_psr, kpi_psa
│ ┌Reemplazos Ση┐┌Saltos de cola Σσ┐┌Salidas demoradas · ΣΔt┐┌Ret(X)┐┌Tm(X)┐   │  kpi_reemplazos, kpi_saltos
│ «Sin datos para el periodo» si no hay programaciones aprobadas            │  reporte_sin_datos
```

Código: `pantalla_reportes.dart`, `vistas/exportacion/` (descarga en la web,
carpeta de descargas en escritorio) · `ReportesControlador` ·
captura [`operaciones_reportes.png`](capturas/operaciones_reportes.png).

## Administración: parámetros y bitácora

Capturas [`administrador_parametros.png`](capturas/administrador_parametros.png)
(solo lectura: se cambian en `config/parametros.yaml`) y
[`administrador_bitacora.png`](capturas/administrador_bitacora.png).
