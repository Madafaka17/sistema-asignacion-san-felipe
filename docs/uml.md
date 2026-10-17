# Diagramas UML (versión final, según lo construido)

Los diagramas reflejan el código de la versión `v1.2.0`: cada clase, método
y ruta que aparece aquí existe con ese nombre en el repositorio. Las
diferencias con el diseño de la tesis están en
[`decisiones_y_desviaciones.md`](decisiones_y_desviaciones.md).
GitHub dibuja los bloques Mermaid directamente.

Índice: [1. Casos de uso](#1-casos-de-uso) ·
[2. Componentes](#2-componentes) ·
[3. Clases del núcleo (dominio)](#3-clases-del-núcleo-paquete-dominio) ·
[4. Clases del servidor](#4-clases-del-servidor) ·
[5. Clases del cliente (MVC)](#5-clases-del-cliente-mvc) ·
[6. Secuencia: generar la programación](#6-secuencia-generar-la-programación-hu-07) ·
[7. Secuencia: registrar un servicio](#7-secuencia-registrar-un-servicio-hu-06-ciclo-completo) ·
[8. Secuencia: sesión y renovación](#8-secuencia-ingreso-y-renovación-de-la-sesión-hu-01) ·
[9. Actividad](#9-actividad-flujo-operativo-figura-5-de-la-tesis) ·
[10. Despliegue](#10-despliegue) ·
[11. Entidad–relación](#11-entidadrelación)

---

## 1. Casos de uso

```mermaid
flowchart LR
  despacho(["👤 Personal de despacho"])
  operaciones(["👤 Encargado de operaciones"])
  admin(["👤 Administrador"])

  subgraph Sistema de asignación de recursos
    UC01a([HU-01 Ingresar al sistema])
    UC01b([HU-01 Registrar usuarios y roles])
    UC02([HU-02 Registrar vehículos])
    UC03([HU-03 Registrar conductores])
    UC04([HU-04 Registrar rutas])
    UC05([HU-05 Registrar salidas autorizadas])
    UC06([HU-06 Registrar servicios del turno])
    UCC([Registrar la cola de despacho])
    UCP2([Registrar conductor habitual y reemplazos])
    UC07([HU-07 Generar la programación])
    UC08([HU-08 Revisar la propuesta])
    UC09([HU-09 Ajustar y aprobar])
    UC10([HU-10 Registrar incidencias])
    UC11([HU-11 Reporte de indicadores])
    UCP([Consultar parámetros y bitácora])
  end

  despacho --- UC01a & UC02 & UC03 & UC04 & UC05 & UC06 & UCC & UCP2 & UC10
  UC06 -. «include» .-> UCC
  UC02 -. «extend» .-> UCP2
  operaciones --- UC01a & UC07 & UC08 & UC09 & UC11
  admin --- UC01a & UC01b & UCP
  UC07 -. «include» .-> UC08
  UC09 -. «include» .-> UC08
```

Los módulos de cada actor salen de la matriz `Permisos`
(`paquetes/dominio/lib/src/modelos/usuario.dart`), que comparten el servidor
(autorización de cada solicitud) y el cliente (navegación).

---

## 2. Componentes

```mermaid
flowchart TB
  subgraph Cliente["cliente/ (Flutter: web, Windows, Linux)"]
    V["Vistas<br/>vistas/pantallas, vistas/componentes"]
    C["Controladores<br/>controladores/*_controlador(es).dart"]
    M["Modelo<br/>modelo/repositorios + modelo/api/ApiCliente"]
    V -- acciones --> C
    C -- notifyListeners --> V
    C --> M
  end

  subgraph Dominio["paquetes/dominio (Dart puro, compartido)"]
    CT["contrato<br/>versión, errores, LectorJson, Pagina"]
    MO["modelos<br/>Vehiculo, Conductor, Ruta, Programacion…"]
    OP["optimizacion<br/>ConstructorInstancia, Evaluador,<br/>AlgoritmoGenetico, AlgoritmoVoraz, Validador"]
  end

  subgraph Servidor["servidor/ (Dart + shelf)"]
    R["http: Router + middleware"]
    CS["controladores"]
    S["servicios (lógica de negocio)"]
    RP["repositorios (SQL)"]
    R --> CS --> S --> RP
    S --> OP
  end

  BD[("MySQL 8.4<br/>basedatos/esquema.sql")]
  CFG[/"config/parametros.yaml"/]

  M -- "HTTP/JSON · JWT · X-Version-Cliente" --> R
  RP -- "mysql_client_plus · TLS" --> BD
  S --- CFG
  Cliente -. usa .-> CT & MO
  Servidor -. usa .-> CT & MO
```

---

## 3. Clases del núcleo (paquete `dominio`)

Patrones: **Strategy** (`EstrategiaOptimizacion`), **Factory**
(`FabricaEstrategias`) y objetos de valor inmutables.

```mermaid
classDiagram
  direction LR
  class EstrategiaOptimizacion {
    <<interface>>
    +String id
    +resolver(InstanciaTurno) ResultadoOptimizacion
  }
  class AlgoritmoGenetico {
    +ParametrosAG parametros
    +resolver(InstanciaTurno) ResultadoOptimizacion
    -_torneo(aptitudes, aleatorio) int
    -_cruceUniforme(p1, p2, aleatorio) List~int~
    -_mutar(cromosoma, servicios, aleatorio) List~int~
  }
  class AlgoritmoVoraz {
    +resolver(InstanciaTurno) ResultadoOptimizacion
  }
  class FabricaEstrategias {
    +crear(metodo, parametrosAG)$ EstrategiaOptimizacion
    +metodosDisponibles$ List~String~
  }
  class ConstructorInstancia {
    +ParametrosModelo parametros
    +construir(DatosTurno) InstanciaTurno
    -_salidasCandidatas(servicio, salidas) List~SalidaAutorizada~
    -_diagnosticar(...) String
  }
  class DatosTurno {
    +List~ServicioProgramado~ servicios
    +List~EntradaCola~ entradas
    +List~ParAutorizado~ pares
    +Map~int, Alternativa~ comprometidas
  }
  class ExcepcionesAsignacion {
    +bool saltoCola «σ»
    +bool reemplazo «η»
    +int demoraMin «Δt»
    +int? vehiculoCola «v0»
    +int? conductorHabitual «chab»
    +String? explicacion
    +de(instancia, servicio, alternativa)$ ExcepcionesAsignacion
    +bool requiereJustificacion
  }
  class Evaluador {
    +decodificar(alfa) Map~int, Alternativa~
    +evaluar(alfa) Evaluacion
    +evaluarProgramacion(Map) Evaluacion
  }
  class Reparador {
    +int pasadasMaximas
    +reparar(cromosoma) List~int~
  }
  class Decodificador {
    +decodificar(cromosoma) List~ResultadoServicio~
  }
  class Validador {
    +int holguraMinima
    +validar(asignaciones, limites) ResultadoValidacion
  }
  class InstanciaTurno {
    +List~ServicioTurno~ servicios
    +List~ServicioTurno~ admisibles
    +Map~int, ConductorTurno~ conductores
    +Map~int, int~ habituales «chab»
    +int holguraMinima
    +double penalizacion
  }
  class ResultadoOptimizacion {
    +String metodo
    +List~int~ cromosoma
    +Evaluacion evaluacion
    +int generaciones
    +List~PuntoConvergencia~ historial
  }
  class ParametrosAG
  class ParametrosModelo

  EstrategiaOptimizacion <|.. AlgoritmoGenetico
  EstrategiaOptimizacion <|.. AlgoritmoVoraz
  FabricaEstrategias ..> EstrategiaOptimizacion : crea
  AlgoritmoGenetico --> Evaluador
  AlgoritmoGenetico --> Reparador
  AlgoritmoGenetico --> ParametrosAG
  AlgoritmoVoraz --> Evaluador
  ConstructorInstancia --> ParametrosModelo
  ConstructorInstancia ..> InstanciaTurno : crea
  ConstructorInstancia ..> DatosTurno : lee
  ExcepcionesAsignacion ..> InstanciaTurno
  Evaluador --> InstanciaTurno
  Reparador --> InstanciaTurno
  Decodificador --> InstanciaTurno
  EstrategiaOptimizacion ..> ResultadoOptimizacion
```

Modelos de datos compartidos (todos con `toJson`/`fromJson` del contrato):

```mermaid
classDiagram
  direction LR
  class Vehiculo {
    +int id
    +String codigo
    +String placa
    +int capacidad
    +CategoriaVehiculo categoria
    +EstadoVehiculo estado
    +bool disponible
  }
  class Conductor {
    +int id
    +String codigo
    +String dni
    +CategoriaLicencia categoriaLicencia
    +DateTime vencimientoLicencia
    +int turnoInicio
    +int turnoFin
    +int minutosAcumulados
    +int limiteMinutos
    +bool disponible
    +licenciaVigente(fecha) bool
  }
  class Ruta {
    +int id
    +String codigo
    +String origen
    +String destino
    +int duracionMin «viaje redondo»
    +int? idaMin «ida declarada»
    +bool activa
    +List~int~ vehiculosCompatibles
  }
  class SalidaAutorizada {
    +int id
    +int rutaId
    +int hora
    +int? duracionMin
  }
  class ServicioProgramado {
    +int id
    +String codigo
    +DateTime fecha
    +int rutaId
    +int horaSolicitada
    +int prioridad
    +int capacidadRequerida
    +EstadoServicio estado
    +int? entradaColaId «v0(s), π(s)»
  }
  class EntradaCola {
    +int id
    +int rutaId
    +DateTime fecha
    +int vehiculoId
    +int posicion «π»
    +int llegada
    +bool activa
    +int? servicioId
    +bool libre
  }
  class ParAutorizado {
    +int vehiculoId
    +int conductorId
    +TipoPar tipo «habitual | reemplazo»
  }
  class ConductoresAutorizados {
    +int vehiculoId
    +int? conductorHabitualId
    +List~int~ reemplazos
    +porVehiculo(pares)$ Map
  }
  class Programacion {
    +int id
    +DateTime fecha
    +EstadoProgramacion estado
    +int version
    +int ejecucionId
    +String? huellaEntrada
    +String versionAlgoritmo
    +int tiempoNucleoMs
    +String metodo
    +double aptitud
    +int phi
    +int phiValidador
    +ComponentesAptitud componentes
    +List~Asignacion~ asignaciones
    +List~PuntoConvergencia~ historial
  }
  class Asignacion {
    +int servicioId
    +int? vehiculoId
    +int? conductorId
    +int? salida
    +int? fin
    +EstadoAsignacion estado
    +String? motivo
    +bool ajustada
    +bool saltoCola
    +bool reemplazo
    +int demoraMin
    +String? justificacion
  }
  class Incidencia {
    +int id
    +String codigoServicio
    +TipoIncidencia tipo
    +DateTime fecha
    +int hora
    +int? minutosRetraso
    +int? vehiculoId
    +int? conductorId
  }
  class Usuario {
    +int id
    +String nombreUsuario
    +String nombreCompleto
    +Rol rol
    +bool activo
  }
  class Permisos {
    +puedeLeer(rol, modulo)$ bool
    +puedeEscribir(rol, modulo)$ bool
    +modulosNavegacion(rol)$ List~Modulo~
  }
  Ruta "1" o-- "*" SalidaAutorizada
  Ruta "*" o-- "*" Vehiculo : κ(v, r)
  ServicioProgramado "*" --> "1" Ruta
  ServicioProgramado "0..1" --> "0..1" EntradaCola : turno
  EntradaCola "*" --> "1" Vehiculo
  ParAutorizado "*" --> "1" Vehiculo
  ParAutorizado "*" --> "1" Conductor
  ConductoresAutorizados "1" o-- "*" ParAutorizado
  Programacion "1" *-- "*" Asignacion
  Asignacion "*" --> "1" ServicioProgramado
  Incidencia "*" --> "1" ServicioProgramado
```

---

## 4. Clases del servidor

Capas **Router → Controlador → Servicio → Repositorio → MySQL**. Los
controladores no tienen SQL ni reglas de negocio; los servicios no conocen
HTTP; solo los repositorios escriben SQL. Patrón **Repository** (interfaz +
implementación MySQL) y **raíz de composición** (`crearAplicacion`).

```mermaid
classDiagram
  direction TB
  class crearAplicacion {
    <<raíz de composición>>
    +crearAplicacion(bd, configuracion, parametros, reloj) Handler
  }
  class ProgramacionControlador {
    +registrar(Router)
    POST /api/programaciones
    GET /api/programaciones/:id
    PUT /api/programaciones/:id/asignaciones/:servicio
    POST /api/programaciones/:id/aprobar
  }
  class ServicioProgramadoControlador {
    +registrar(Router)
    GET|POST /api/servicios
  }
  class ProgramacionServicio {
    +generar(fecha, usuario) Programacion
    +ajustar(id, servicioId, ajuste, usuario) Programacion «versión nueva»
    +aprobar(id, usuario) Programacion
    +entrada(id) SnapshotEntrada
    -_instancia(fecha) (InstanciaTurno, DatosTurno, int)
    -_registrarEntrada(tx, datos) (int, String)
    -_exigirVigente(id, estado, accion)
  }
  class ServicioProgramadoServicio {
    +listar(pagina, fecha, estado)
    +crear(servicio, autor) ServicioProgramado
    +cancelar(id, autor)
  }
  class ServicioConBitacora {
    <<abstract>>
    #registrar(usuario, accion, entidad, id, detalle)
  }
  class RepositorioProgramaciones {
    <<interface>>
    +guardar(tx, NuevaProgramacion) int
    +buscar(id) Programacion?
    +comprometidas(fecha) Map
    +bloquear(tx, id) EstadoProgramacion?
    +crearVersion(tx, anteriorId, snapshotId, ...) int
    +marcarSustituida(tx, id)
    +aprobar(tx, id, usuarioId, momento)
  }
  class RepositorioProgramacionesMysql
  class RepositorioServicios {
    <<interface>>
    +deFecha(fecha, estados) List
    +crear(servicio, usuarioId) int
  }
  class RepositorioServiciosMysql
  class BaseDatos {
    +consultar(sql, parametros) List~Fila~
    +ejecutar(sql, parametros) ResultadoEscritura
    +transaccion(accion) T
  }
  class Ejecutor {
    <<interface>>
  }
  class AutenticacionServicio {
    +ingresar(usuario, contrasena) SesionEmitida
    +refrescar(token) SesionEmitida
    +salir(token)
  }
  class Tokens {
    +emitirAcceso(usuario) String
    +verificarAcceso(token) UsuarioAutenticado?
  }
  class Contrasenas {
    +resumir(clave) String
    +verificar(clave, resumen) bool
  }
  class Reloj {
    <<interface>> +ahora() DateTime
  }

  crearAplicacion ..> ProgramacionControlador
  crearAplicacion ..> ServicioProgramadoControlador
  ProgramacionControlador --> ProgramacionServicio
  ServicioProgramadoControlador --> ServicioProgramadoServicio
  ServicioConBitacora <|-- ServicioProgramadoServicio
  ProgramacionServicio --> RepositorioProgramaciones
  ProgramacionServicio --> RepositorioServicios
  ProgramacionServicio ..> FabricaEstrategias
  ProgramacionServicio ..> ConstructorInstancia
  ServicioProgramadoServicio --> RepositorioServicios
  RepositorioProgramaciones <|.. RepositorioProgramacionesMysql
  RepositorioServicios <|.. RepositorioServiciosMysql
  RepositorioProgramacionesMysql --> BaseDatos
  RepositorioServiciosMysql --> BaseDatos
  Ejecutor <|.. BaseDatos
  AutenticacionServicio --> Tokens
  AutenticacionServicio --> Contrasenas
  ProgramacionServicio --> Reloj
```

El diagrama muestra en detalle el caso de uso principal; los demás recursos
siguen el mismo patrón (un controlador, un servicio y un repositorio por
recurso):

| Recurso | Controlador | Servicio | Repositorio |
|---|---|---|---|
| Sesión | `AutenticacionControlador` | `AutenticacionServicio` | `RepositorioUsuarios`, `RepositorioSesiones` |
| Usuarios | `UsuarioControlador` | `UsuarioServicio` | `RepositorioUsuarios` |
| Vehículos y conductores autorizados | `VehiculoControlador` | `VehiculoServicio` | `RepositorioVehiculos`, `RepositorioPares` |
| Conductores | `ConductorControlador` | `ConductorServicio` | `RepositorioConductores` |
| Rutas y salidas | `RutaControlador` | `RutaServicio` | `RepositorioRutas` |
| Servicios | `ServicioProgramadoControlador` | `ServicioProgramadoServicio` | `RepositorioServicios`, `RepositorioCola` |
| Cola de despacho | `ColaControlador` | `ColaServicio` | `RepositorioCola` |
| Programación | `ProgramacionControlador` | `ProgramacionServicio` | `RepositorioProgramaciones`, `RepositorioSnapshots` (+ los de registros, `RepositorioCola` y `RepositorioPares`) |
| Incidencias | `IncidenciaControlador` | `IncidenciaServicio` | `RepositorioIncidencias` |
| Reportes, bitácora, parámetros | `ReporteControlador` | `ReporteServicio`, `BitacoraServicio`, `ParametrosServicio` | `RepositorioReportes`, `RepositorioBitacora` |

Middleware, en orden: `cabecerasComunes` → `cors` → `registrarSolicitudes` →
`manejarErrores` → `verificarVersionCliente` → `autenticar` → `Router`.

---

## 5. Clases del cliente (MVC)

```mermaid
classDiagram
  direction LR
  class PantallaProgramacion {
    <<Vista>>
    +build(context) Widget
  }
  class BotonAsincrono {
    <<Vista · componente>>
    +alPresionar Future Function()
    desactivado mientras la acción está en curso
  }
  class ControladorBase {
    <<Controlador>>
    +bool ocupado
    +String? error
    +Map erroresCampo
    #ejecutar(accion) T?
  }
  class ChangeNotifier
  class ProgramacionControlador {
    +generar() bool
    +ajustar(asignacion, ajuste) bool
    +aprobar() bool
    +asignaciones List~Asignacion~
    +puedeAprobar bool
  }
  class ServiciosControlador {
    +cargar()
    +cargarRuta(rutaId)
    +turnosDisponibles(rutaId, hora) List~EntradaCola~
    +guardar(servicio) bool
    +cancelar(servicio) bool
  }
  class ColaControlador {
    +cargar()
    +seleccionarRuta(rutaId)
    +registrarLlegada(vehiculoId, llegada) bool
    +retirar(entrada) bool
  }
  class RepositorioCola {
    <<interface · Modelo>>
    +entradas(fecha, rutaId) List~EntradaCola~
    +registrar(solicitud) EntradaCola
    +retirar(id) EntradaCola
  }
  class SesionControlador {
    +ingresar(usuario, clave) bool
    +salir()
    +modulos List~Modulo~
  }
  class RepositorioProgramaciones {
    <<interface · Modelo>>
    +generar(fecha) Programacion
    +obtener(id) Programacion
    +ajustar(...) Programacion
    +aprobar(id) Programacion
  }
  class RepositorioProgramacionesApi
  class RepositorioServicios {
    <<interface · Modelo>>
  }
  class RepositorioServiciosApi
  class ApiCliente {
    <<Modelo>>
    -String? _tokenAcceso
    +get/post/put/delete(ruta)
    +ingresar(usuario, clave) SesionIniciada
    +reanudar() SesionIniciada?
    -_renovar() bool
  }

  ChangeNotifier <|-- ControladorBase
  ControladorBase <|-- ProgramacionControlador
  ControladorBase <|-- ServiciosControlador
  ControladorBase <|-- ColaControlador
  ServiciosControlador --> RepositorioCola
  ColaControlador --> RepositorioCola
  ControladorBase <|-- SesionControlador
  PantallaProgramacion ..> ProgramacionControlador : watch / acciones
  PantallaProgramacion *-- BotonAsincrono
  ProgramacionControlador --> RepositorioProgramaciones
  ServiciosControlador --> RepositorioServicios
  RepositorioProgramaciones <|.. RepositorioProgramacionesApi
  RepositorioServicios <|.. RepositorioServiciosApi
  RepositorioProgramacionesApi --> ApiCliente
  RepositorioServiciosApi --> ApiCliente
  SesionControlador --> ApiCliente
```

Regla de capas (verificable con `grep`): ningún archivo de
`cliente/lib/controladores/` ni de `cliente/lib/vistas/` importa
`package:http`; solo `cliente/lib/modelo/api/` lo hace.

---

## 6. Secuencia: generar la programación (HU-07)

```mermaid
sequenceDiagram
  autonumber
  actor Op as Encargado de operaciones
  participant V as PantallaProgramacion
  participant C as ProgramacionControlador
  participant A as ApiCliente
  participant MW as Middleware
  participant PC as ProgramacionControlador (servidor)
  participant PS as ProgramacionServicio
  participant R as Repositorios
  participant N as Núcleo (isolate)
  participant BD as MySQL

  Op->>V: pulsa «Generar programación»
  V->>C: generar()
  Note over V,C: BotonAsincrono y ocupado = true<br/>desactivan el botón
  C->>A: RepositorioProgramaciones.generar(fecha)
  A->>MW: POST /api/programaciones {fecha}<br/>Bearer JWT · X-Version-Cliente
  MW->>PC: usuario autenticado
  PC->>PC: autorizar(Modulo.programacion, escritura)
  PC->>PS: generar(fecha, usuario)
  PS->>R: servicios.deFecha(pendientes)
  R->>BD: SELECT
  alt no hay pendientes
    PS-->>A: 422 «No hay servicios pendientes…»
  end
  PS->>R: vehículos, conductores, rutas, salidas, colas, pares, comprometidas
  R->>BD: SELECT
  PS->>PS: ConstructorInstancia.construir → A_s (ec. 1 con v ∈ {v0, v1} y c ∈ {chab} ∪ C^R)
  PS->>N: Isolate.run(AlgoritmoGenetico.resolver)
  N-->>PS: ResultadoOptimizacion (α, F, Φ, historial)
  PS->>PS: Decodificador (incidencias) y Validador (Φ independiente)
  PS->>PS: ExcepcionesAsignacion.de → σ, η, Δt y su explicación
  PS->>BD: transacción: programacion + asignacion + historial_aptitud + bitacora
  PS-->>PC: Programacion
  PC-->>A: 201 Created + JSON
  A-->>C: Programacion
  C->>C: actual = propuesta y notifyListeners()
  C-->>V: reconstruye: KPI, tabla (incidencias primero), Gantt, convergencia
```

---

## 7. Secuencia: registrar un servicio (HU-06, ciclo completo)

Es el flujo que verifica `cliente/integration_test/ciclo_completo_test.dart`.

```mermaid
sequenceDiagram
  autonumber
  actor D as Personal de despacho
  participant F as Formulario (DialogoFormulario)
  participant C as ServiciosControlador
  participant A as ApiCliente
  participant S as Servidor
  participant BD as MySQL

  D->>F: completa código, ruta, hora autorizada, prioridad, asientos
  D->>F: pulsa «Guardar»
  F->>F: valida en el cliente (ruta obligatoria, hora autorizada)
  F->>C: guardar(servicio)
  Note over F: botón desactivado: un segundo toque<br/>no envía otra solicitud
  C->>A: POST /api/servicios {codigo, fecha, rutaId, horaSolicitada, prioridad, capacidadRequerida}
  A->>S: HTTP
  S->>S: LectorJson (tipos) → reglas: ruta activa, salida autorizada, código único
  S->>BD: INSERT servicio + INSERT bitacora
  S-->>A: 201 Created {id, …, estado: "pendiente"}
  A-->>C: ServicioProgramado
  C->>C: inserta en la lista y notifyListeners()
  C-->>F: true → cierra el diálogo
  Note over C: la tabla muestra la fila nueva<br/>sin volver a pedir GET /api/servicios
```

---

## 8. Secuencia: ingreso y renovación de la sesión (HU-01)

```mermaid
sequenceDiagram
  autonumber
  participant U as Usuario
  participant A as ApiCliente
  participant S as AutenticacionServicio
  participant BD as MySQL

  U->>A: ingresar(usuario, contraseña)
  A->>S: POST /api/auth/ingresar
  S->>BD: usuario, intentos_fallidos, bloqueado_hasta
  alt contraseña incorrecta (5.º intento)
    S->>BD: bloqueado_hasta = ahora + 15 min, bitácora «bloqueo_cuenta»
    S-->>A: 423 «Cuenta bloqueada temporalmente»
  else correcta
    S->>BD: INSERT sesion (SHA-256 del token de actualización)
    S-->>A: 200 {tokenAcceso (JWT 15 min), usuario}<br/>Set-Cookie: refresco=… (HttpOnly, SameSite=Strict, Secure)
  end
  Note over A: el JWT queda solo en memoria
  A->>S: GET /api/… → 401 (JWT vencido)
  A->>S: POST /api/auth/refrescar (cookie)
  S->>BD: revoca la sesión anterior, crea otra (rotación)
  S-->>A: 200 {nuevo tokenAcceso} + nueva cookie
  A->>S: repite la solicitud original
```

---

## 9. Actividad: flujo operativo (Figura 5 de la tesis)

```mermaid
flowchart TD
  I((Inicio)) --> R1[Despacho registra vehículos, conductores,<br/>rutas, salidas y servicios del turno]
  R1 --> G[Operaciones genera la programación]
  G --> P{¿Hay servicios<br/>pendientes?}
  P -- No --> E1[/«No hay servicios pendientes»/] --> F((Fin))
  P -- Sí --> SN[Guardar el snapshot de la entrada<br/>con su SHA-256]
  SN --> M[Construir A_s y ejecutar el método<br/>configurado en parametros.yaml]
  M --> V[Validador independiente: Φ]
  V --> RV[Revisar la propuesta: incidencias primero,<br/>Gantt y convergencia]
  RV --> AJ{¿Ajustar alguna<br/>asignación?}
  AJ -- Sí --> A1[Ajuste manual: alternativa admisible y motivo<br/>→ versión nueva; la anterior queda sustituida] --> V
  AJ -- No --> Q{¿Φ = 0?}
  Q -- No --> RV
  Q -- Sí --> AP[Aprobar: queda en la bitácora;<br/>servicios → programado]
  AP --> OP[Operación del turno]
  OP --> INC{¿Incidencia?}
  INC -- Sí --> RI[Despacho registra la incidencia]
  RI --> RP{¿Indisponibilidad?}
  RP -- Sí --> PEN[El servicio vuelve a pendiente] --> G
  RP -- No --> OP
  INC -- No --> REP[Operaciones genera el reporte de indicadores] --> F
```

### Estados de una versión de programación (CU-07, CU-09 y CU-12)

```mermaid
stateDiagram-v2
  [*] --> propuesta : generar (versión 1, con snapshot)
  propuesta --> propuesta : ajustar → versión siguiente
  propuesta --> sustituida : un ajuste creó la versión siguiente
  propuesta --> aprobada : aprobar (Φ = 0, versión vigente, fila bloqueada)
  aprobada --> reemplazada : se aprueba otra programación de la misma fecha
  sustituida --> [*]
  reemplazada --> [*]
  note right of sustituida
    ajustar o aprobar una versión sustituida → 409;
    sus asignaciones no cambian
  end note
```

---

## 10. Despliegue

```mermaid
flowchart LR
  subgraph PCs["Equipos de la empresa"]
    NAV["Navegador<br/>(cliente web)"]
    ESC["Cliente de escritorio<br/>Windows / Linux"]
  end

  subgraph SRV["Equipo servidor · Docker Compose (proyecto «sanfelipe»)"]
    direction TB
    NG["cliente<br/>nginx 1.28 + Flutter web<br/>:80 → 127.0.0.1:3000"]
    API["servidor<br/>Dart AOT (scratch, ~20 MB)<br/>:8080 → 127.0.0.1:8080"]
    DB[("basedatos<br/>MySQL 8.4.11<br/>:3306 → 127.0.0.1:3306")]
    VOL[("volumen<br/>datos_mysql")]
    YAML[/"config/parametros.yaml<br/>(montado, solo lectura)"/]
    NG -- "/api/* (proxy inverso)" --> API
    API -- "TLS · pool de conexiones" --> DB
    DB --- VOL
    API --- YAML
  end

  NAV -- "HTTP(S) :3000" --> NG
  ESC -- "HTTP(S) :8080/api" --> API
  RES[["herramientas/respaldo.sh<br/>mysqldump diario"]] -.-> DB
```

---

## 11. Entidad–relación

```mermaid
erDiagram
  USUARIO ||--o{ SESION : "tokens de actualización"
  USUARIO ||--o{ BITACORA : "registra"
  USUARIO ||--o{ SERVICIO : "creado_por"
  USUARIO ||--o{ PROGRAMACION : "creado_por / aprobado_por"
  SNAPSHOT_ENTRADA ||--o{ PROGRAMACION : "entrada de la versión"
  PROGRAMACION ||--o{ PROGRAMACION : "ejecución / versión anterior"
  RUTA ||--o{ SALIDA_AUTORIZADA : "tiene"
  RUTA ||--o{ RUTA_VEHICULO : ""
  VEHICULO ||--o{ RUTA_VEHICULO : "compatible"
  VEHICULO ||--o{ PAR_AUTORIZADO : "chab(v), C_v^R"
  CONDUCTOR ||--o{ PAR_AUTORIZADO : ""
  RUTA ||--o{ COLA : "por fecha"
  COLA ||--o{ ENTRADA_COLA : "π"
  VEHICULO ||--o{ ENTRADA_COLA : "llega"
  ENTRADA_COLA |o--o| SERVICIO : "v0(s)"
  SALIDA_AUTORIZADA ||--o{ SERVICIO : "(ruta_id, hora)"
  PROGRAMACION ||--o{ ASIGNACION : "contiene"
  PROGRAMACION ||--o{ HISTORIAL_APTITUD : "convergencia"
  SERVICIO ||--o{ ASIGNACION : ""
  VEHICULO ||--o{ ASIGNACION : ""
  CONDUCTOR ||--o{ ASIGNACION : ""
  SERVICIO ||--o{ INCIDENCIA : ""
  VEHICULO ||--o{ INCIDENCIA : ""
  CONDUCTOR ||--o{ INCIDENCIA : ""

  VEHICULO {
    int id PK
    string codigo UK
    string placa UK
    int capacidad
    enum categoria
    enum estado
  }
  CONDUCTOR {
    int id PK
    string codigo UK
    string dni UK
    enum categoria_licencia
    date vencimiento_licencia
    int turno_inicio
    int turno_fin
    int minutos_acumulados
    int limite_minutos
    bool disponible
  }
  RUTA {
    int id PK
    string codigo UK
    string origen
    string destino
    int duracion_min
    int ida_min
    bool activa
  }
  PAR_AUTORIZADO {
    int vehiculo_id PK
    int conductor_id PK
    enum tipo
    int habitual_vehiculo UK
    int habitual_conductor UK
  }
  COLA {
    int id PK
    int ruta_id FK
    date fecha
  }
  ENTRADA_COLA {
    int id PK
    int cola_id FK
    int vehiculo_id FK
    int posicion
    int llegada
    bool activa
  }
  SALIDA_AUTORIZADA {
    int id PK
    int ruta_id FK
    int hora
    int duracion_min
  }
  SERVICIO {
    int id PK
    string codigo UK
    date fecha
    int ruta_id FK
    int hora_solicitada FK
    int prioridad
    int capacidad_requerida
    enum estado
    int entrada_cola_id FK
    int entrada_vigente UK
  }
  PROGRAMACION {
    int id PK
    date fecha
    enum estado
    int version
    int ejecucion_id FK
    int version_anterior_id FK
    int snapshot_id FK
    string metodo
    string version_algoritmo
    double aptitud
    int phi
    int phi_validador
    int tiempo_ms
    int tiempo_nucleo_ms
    json parametros
    date fecha_aprobada UK
  }
  SNAPSHOT_ENTRADA {
    int id PK
    date fecha
    string sha256 UK
    text contenido
  }
  ASIGNACION {
    int id PK
    int programacion_id FK
    int servicio_id FK
    int vehiculo_id FK
    int conductor_id FK
    int salida
    int fin
    enum estado
    string motivo
    bool ajustada
    bool salto_cola
    bool reemplazo
    int demora_min
    int vehiculo_cola_id FK
    int conductor_habitual_id FK
    string justificacion
  }
  INCIDENCIA {
    int id PK
    int servicio_id FK
    enum tipo
    date fecha
    int hora
    int minutos_retraso
    string descripcion
  }
  USUARIO {
    int id PK
    string nombre_usuario UK
    string hash_contrasena
    enum rol
    int intentos_fallidos
    datetime bloqueado_hasta
  }
```

La correspondencia de cada tabla con los conjuntos y parámetros del modelo
está en [`modelo_datos.md`](modelo_datos.md).
