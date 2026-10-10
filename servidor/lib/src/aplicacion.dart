import 'package:dominio/dominio.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'configuracion/configuracion.dart';
import 'configuracion/parametros_sistema.dart';
import 'controladores/autenticacion_controlador.dart';
import 'controladores/operacion_controlador.dart';
import 'controladores/registros_controlador.dart';
import 'http/http_util.dart';
import 'http/middleware.dart';
import 'infraestructura/base_datos.dart';
import 'infraestructura/reloj.dart';
import 'repositorios/repositorio_bitacora.dart';
import 'repositorios/repositorio_conductores.dart';
import 'repositorios/repositorio_incidencias.dart';
import 'repositorios/repositorio_programaciones.dart';
import 'repositorios/repositorio_reportes.dart';
import 'repositorios/repositorio_rutas.dart';
import 'repositorios/repositorio_servicios.dart';
import 'repositorios/repositorio_sesiones.dart';
import 'repositorios/repositorio_usuarios.dart';
import 'repositorios/repositorio_vehiculos.dart';
import 'seguridad/contrasenas.dart';
import 'seguridad/tokens.dart';
import 'servicios/autenticacion_servicio.dart';
import 'servicios/operacion_servicio.dart';
import 'servicios/programacion_servicio.dart';
import 'servicios/registros_servicio.dart';

/// Versión del ejecutable del servidor (independiente de la del contrato).
const versionServidor = '1.0.0';

/// Raíz de composición: el único lugar donde se crean y conectan las capas
/// (inyección de dependencias manual).
///
/// ```text
/// Router → Controlador → Servicio → Repositorio → MySQL
///                           └→ núcleo de optimización (paquete dominio)
/// ```
///
/// Los controladores solo traducen HTTP ⇄ objetos del contrato; las reglas
/// de negocio están en los servicios y el SQL, solo en los repositorios.
Handler crearAplicacion({
  required BaseDatos bd,
  required Configuracion configuracion,
  required ParametrosSistema parametros,
  Reloj? reloj,
}) {
  final relojEfectivo = reloj ?? RelojSistema(desfaseMinutos: configuracion.desfaseHorarioMin);

  // Repositorios (capa de datos).
  final repoUsuarios = RepositorioUsuariosMysql(bd);
  final repoSesiones = RepositorioSesionesMysql(bd);
  final repoBitacora = RepositorioBitacoraMysql(bd);
  final repoVehiculos = RepositorioVehiculosMysql(bd);
  final repoConductores = RepositorioConductoresMysql(bd);
  final repoRutas = RepositorioRutasMysql(bd);
  final repoServicios = RepositorioServiciosMysql(bd);
  final repoProgramaciones = RepositorioProgramacionesMysql(bd);
  final repoIncidencias = RepositorioIncidenciasMysql(bd);
  final repoReportes = RepositorioReportesMysql(bd);

  // Seguridad.
  final contrasenas = Contrasenas(iteraciones: parametros.iteracionesPbkdf2);
  final tokens = Tokens(
    secreto: configuracion.jwtSecreto,
    duracionAcceso: Duration(minutes: configuracion.minutosToken),
  );

  // Servicios (lógica de negocio).
  final autenticacion = AutenticacionServicio(
    bd: bd,
    usuarios: repoUsuarios,
    sesiones: repoSesiones,
    bitacora: repoBitacora,
    contrasenas: contrasenas,
    tokens: tokens,
    reloj: relojEfectivo,
    parametros: parametros,
    duracionActualizacion: Duration(days: configuracion.diasRefresco),
  );
  final servicioUsuarios = UsuarioServicio(
    bd: bd,
    bitacora: repoBitacora,
    reloj: relojEfectivo,
    usuarios: repoUsuarios,
    contrasenas: contrasenas,
  );
  final servicioVehiculos =
      VehiculoServicio(bd: bd, bitacora: repoBitacora, reloj: relojEfectivo, vehiculos: repoVehiculos);
  final servicioConductores =
      ConductorServicio(bd: bd, bitacora: repoBitacora, reloj: relojEfectivo, conductores: repoConductores);
  final servicioRutas = RutaServicio(
    bd: bd,
    bitacora: repoBitacora,
    reloj: relojEfectivo,
    rutas: repoRutas,
    vehiculos: repoVehiculos,
  );
  final servicioServicios = ServicioProgramadoServicio(
    bd: bd,
    bitacora: repoBitacora,
    reloj: relojEfectivo,
    servicios: repoServicios,
    rutas: repoRutas,
  );
  final servicioProgramacion = ProgramacionServicio(
    bd: bd,
    servicios: repoServicios,
    vehiculos: repoVehiculos,
    conductores: repoConductores,
    rutas: repoRutas,
    programaciones: repoProgramaciones,
    bitacora: repoBitacora,
    parametros: parametros,
    reloj: relojEfectivo,
  );
  final servicioIncidencias = IncidenciaServicio(
    bd: bd,
    incidencias: repoIncidencias,
    servicios: repoServicios,
    programaciones: repoProgramaciones,
    bitacora: repoBitacora,
    reloj: relojEfectivo,
  );

  // Controladores (capa HTTP).
  final enrutador = Router(notFoundHandler: _noEncontrado);
  AutenticacionControlador(
    autenticacion,
    bd,
    cookieSegura: configuracion.cookieSegura,
    versionServidor: versionServidor,
  ).registrar(enrutador);
  UsuarioControlador(servicioUsuarios).registrar(enrutador);
  VehiculoControlador(servicioVehiculos).registrar(enrutador);
  ConductorControlador(servicioConductores).registrar(enrutador);
  RutaControlador(servicioRutas).registrar(enrutador);
  ServicioProgramadoControlador(servicioServicios).registrar(enrutador);
  ProgramacionControlador(servicioProgramacion).registrar(enrutador);
  IncidenciaControlador(servicioIncidencias).registrar(enrutador);
  ReporteControlador(
    ReporteServicio(reportes: repoReportes, parametros: parametros),
    BitacoraServicio(repoBitacora),
    ParametrosServicio(parametros),
  ).registrar(enrutador);

  return const Pipeline()
      .addMiddleware(cabecerasComunes())
      .addMiddleware(cors(configuracion.origenesPermitidos))
      .addMiddleware(registrarSolicitudes())
      .addMiddleware(manejarErrores())
      .addMiddleware(verificarVersionCliente())
      .addMiddleware(autenticar(tokens, rutasPublicas: AutenticacionControlador.rutasPublicas))
      .addHandler(enrutador.call);
}

Response _noEncontrado(Request solicitud) =>
    respuestaError(ExcepcionApi(CodigoError.noEncontrado, 'Recurso no encontrado: /${solicitud.url.path}'));
