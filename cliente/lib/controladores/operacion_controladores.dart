import 'package:dominio/dominio.dart';

import '../modelo/repositorios/operacion_repositorio.dart';
import '../modelo/repositorios/registros_repositorio.dart';
import 'controlador_base.dart';

/// HU-07, HU-08 y HU-09: generar, revisar, ajustar y aprobar la
/// programación del turno (Figura 5 de la tesis).
class ProgramacionControlador extends ControladorBase {
  ProgramacionControlador(this._programaciones, this._vehiculos, this._conductores, {DateTime? hoy})
      : _fecha = _manana(hoy ?? DateTime.now());

  final RepositorioProgramaciones _programaciones;
  final RepositorioVehiculos _vehiculos;
  final RepositorioConductores _conductores;

  DateTime _fecha;
  List<Programacion> _historial = const [];
  Programacion? _actual;
  List<Vehiculo> _flota = const [];
  List<Conductor> _plantilla = const [];
  String? _mensaje;

  static DateTime _manana(DateTime hoy) => DateTime.utc(hoy.year, hoy.month, hoy.day + 1);

  DateTime get fecha => _fecha;

  /// Ejecuciones del turno, la más reciente primero.
  List<Programacion> get historial => _historial;

  /// Propuesta o programación que se está revisando.
  Programacion? get actual => _actual;

  /// Asignaciones en el orden de HU-08: incidencias y cruces primero, luego
  /// por hora de salida.
  List<Asignacion> get asignaciones =>
      _actual == null ? const [] : ([..._actual!.asignaciones]..sort(Asignacion.compararParaVista));

  List<Vehiculo> get vehiculos => _flota;
  List<Conductor> get conductores => _plantilla;

  /// Resultado de la última acción, por ejemplo «Programación aprobada».
  String? get mensaje => _mensaje;

  bool get puedeAprobar =>
      _actual != null && _actual!.estado == EstadoProgramacion.propuesta && _actual!.phiValidador == 0;

  /// El listado del servidor trae solo el resumen de cada ejecución; el
  /// detalle (asignaciones y curva) de la más reciente se pide aparte.
  Future<void> cargar() async {
    final datos = await ejecutar(() async {
      final historial = await _programaciones.listar(_fecha);
      return (
        historial,
        historial.isEmpty ? null : await _programaciones.obtener(historial.first.id),
        await _vehiculos.listar(),
        await _conductores.listar(),
      );
    });
    if (datos == null) return;
    final (historial, actual, flota, plantilla) = datos;
    _historial = historial;
    _actual = actual;
    _flota = flota;
    _plantilla = plantilla;
    notificar();
  }

  Future<void> cambiarFecha(DateTime fecha) async {
    _fecha = DateTime.utc(fecha.year, fecha.month, fecha.day);
    _actual = null;
    _mensaje = null;
    await cargar();
  }

  /// Abre otra ejecución del turno con su detalle.
  Future<void> abrir(Programacion programacion) async {
    _mensaje = null;
    final detalle = await ejecutar(() => _programaciones.obtener(programacion.id));
    if (detalle != null) {
      _actual = detalle;
      notificar();
    }
  }

  /// HU-07. Mientras el método se ejecuta la vista desactiva el botón.
  Future<bool> generar() async {
    _mensaje = null;
    final generada = await ejecutar(() => _programaciones.generar(_fecha));
    if (generada == null) return false;
    _historial = [generada, ..._historial];
    _actual = generada;
    _mensaje = generada.pendientes == 0
        ? 'Propuesta generada: ${generada.asignados} servicios asignados'
        : 'Propuesta generada: ${generada.asignados} asignados y ${generada.pendientes} con incidencia';
    notificar();
    return true;
  }

  /// HU-09, ajuste manual de una asignación.
  Future<bool> ajustar(Asignacion asignacion, AjusteAsignacion ajuste) async {
    final programacion = _actual;
    if (programacion == null) return false;
    final ajustada = await ejecutar(() => _programaciones.ajustar(programacion.id, asignacion.servicioId, ajuste));
    if (ajustada == null) return false;
    _sustituir(ajustada);
    _mensaje = ajustada.phiValidador == 0
        ? 'Ajuste registrado en ${asignacion.codigoServicio}'
        : 'El ajuste genera cruces: resuélvalos antes de aprobar';
    notificar();
    return true;
  }

  /// HU-09, aprobación. El servidor marca como «reemplazada» la que
  /// estuviera aprobada antes para esa fecha, así que se relee el historial.
  Future<bool> aprobar() async {
    final programacion = _actual;
    if (programacion == null) return false;
    final datos = await ejecutar(() async {
      final aprobada = await _programaciones.aprobar(programacion.id);
      return (aprobada, await _programaciones.listar(_fecha));
    });
    if (datos == null) return false;
    final (aprobada, historial) = datos;
    _actual = aprobada;
    _historial = historial;
    _mensaje = 'Programación aprobada';
    notificar();
    return true;
  }

  void _sustituir(Programacion programacion) {
    _historial = [for (final p in _historial) p.id == programacion.id ? programacion : p];
    _actual = programacion;
  }
}

/// HU-10.
class IncidenciasControlador extends ControladorBase {
  IncidenciasControlador(this._repositorio);

  final RepositorioIncidencias _repositorio;

  List<Incidencia> _incidencias = const [];
  List<Incidencia> get incidencias => _incidencias;

  Future<void> cargar() async {
    final lista = await ejecutar(() => _repositorio.listar());
    if (lista != null) {
      _incidencias = lista;
      notificar();
    }
  }

  Future<bool> registrar(SolicitudIncidencia solicitud) async {
    final registrada = await ejecutar(() => _repositorio.registrar(solicitud));
    if (registrada == null) return false;
    _incidencias = [registrada, ..._incidencias];
    notificar();
    return true;
  }
}

/// HU-11.
class ReportesControlador extends ControladorBase {
  ReportesControlador(this._repositorio, {DateTime? hoy}) {
    final h = hoy ?? DateTime.now();
    _desde = DateTime.utc(h.year, h.month);
    _hasta = DateTime.utc(h.year, h.month + 1, 0);
  }

  final RepositorioReportes _repositorio;

  late DateTime _desde;
  late DateTime _hasta;
  ReporteIndicadores? _reporte;

  DateTime get desde => _desde;
  DateTime get hasta => _hasta;
  ReporteIndicadores? get reporte => _reporte;

  void cambiarPeriodo(DateTime desde, DateTime hasta) {
    _desde = DateTime.utc(desde.year, desde.month, desde.day);
    _hasta = DateTime.utc(hasta.year, hasta.month, hasta.day);
    _reporte = null;
    notificar();
  }

  Future<void> generar() async {
    final reporte = await ejecutar(() => _repositorio.indicadores(_desde, _hasta));
    if (reporte != null) {
      _reporte = reporte;
      notificar();
    }
  }

  /// Contenido CSV del reporte para exportarlo.
  Future<String?> exportar() => ejecutar(() => _repositorio.csv(_desde, _hasta));
}

/// Administración: bitácora y parámetros vigentes.
class AdministracionControlador extends ControladorBase {
  AdministracionControlador(this._repositorio);

  final RepositorioAdministracion _repositorio;

  Pagina<EntradaBitacora>? _bitacora;
  Map<String, Object?> _parametros = const {};

  Pagina<EntradaBitacora>? get bitacora => _bitacora;
  Map<String, Object?> get parametros => _parametros;

  Future<void> cargarBitacora({int pagina = 1}) async {
    final datos = await ejecutar(() => _repositorio.bitacora(pagina: pagina));
    if (datos != null) {
      _bitacora = datos;
      notificar();
    }
  }

  Future<void> cargarParametros() async {
    final datos = await ejecutar(_repositorio.parametros);
    if (datos != null) {
      _parametros = datos;
      notificar();
    }
  }
}
