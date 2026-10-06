import 'package:dominio/dominio.dart';

import '../modelo/repositorios/registros_repositorio.dart';
import 'controlador_base.dart';

/// Inserta o reemplaza [elemento] en [lista] según su id: la vista se
/// actualiza con la respuesta 201/200 del servidor, sin volver a pedir la
/// lista (actualización reactiva).
List<T> _reemplazar<T>(List<T> lista, T elemento, int Function(T) id) {
  final i = lista.indexWhere((e) => id(e) == id(elemento));
  return i < 0 ? [...lista, elemento] : ([...lista]..[i] = elemento);
}

/// HU-02.
class VehiculosControlador extends ControladorBase {
  VehiculosControlador(this._repositorio);

  final RepositorioVehiculos _repositorio;

  List<Vehiculo> _vehiculos = const [];
  List<Vehiculo> get vehiculos => _vehiculos;

  Future<void> cargar() async {
    final lista = await ejecutar(_repositorio.listar);
    if (lista != null) {
      _vehiculos = lista;
      notificar();
    }
  }

  Future<bool> guardar(Vehiculo vehiculo) async {
    final guardado = await ejecutar(
      () => vehiculo.id == 0 ? _repositorio.crear(vehiculo) : _repositorio.actualizar(vehiculo),
    );
    if (guardado == null) return false;
    _vehiculos = _reemplazar(_vehiculos, guardado, (v) => v.id);
    notificar();
    return true;
  }
}

/// HU-03.
class ConductoresControlador extends ControladorBase {
  ConductoresControlador(this._repositorio);

  final RepositorioConductores _repositorio;

  List<Conductor> _conductores = const [];
  List<Conductor> get conductores => _conductores;

  Future<void> cargar() async {
    final lista = await ejecutar(_repositorio.listar);
    if (lista != null) {
      _conductores = lista;
      notificar();
    }
  }

  Future<bool> guardar(Conductor conductor) async {
    final guardado = await ejecutar(
      () => conductor.id == 0 ? _repositorio.crear(conductor) : _repositorio.actualizar(conductor),
    );
    if (guardado == null) return false;
    _conductores = _reemplazar(_conductores, guardado, (c) => c.id);
    notificar();
    return true;
  }

  Future<bool> cambiarDisponibilidad(Conductor conductor, bool disponible) async {
    final guardado = await ejecutar(() => _repositorio.cambiarDisponibilidad(conductor.id, disponible));
    if (guardado == null) return false;
    _conductores = _reemplazar(_conductores, guardado, (c) => c.id);
    notificar();
    return true;
  }
}

/// HU-04 y HU-05.
class RutasControlador extends ControladorBase {
  RutasControlador(this._rutas, this._vehiculos);

  final RepositorioRutas _rutas;
  final RepositorioVehiculos _vehiculos;

  List<Ruta> _lista = const [];
  List<Vehiculo> _flota = const [];
  Ruta? _seleccionada;
  List<SalidaAutorizada> _salidas = const [];

  List<Ruta> get rutas => _lista;
  List<Vehiculo> get flota => _flota;
  Ruta? get seleccionada => _seleccionada;
  List<SalidaAutorizada> get salidas => _salidas;

  Future<void> cargar() async {
    final datos = await ejecutar(() async => (await _rutas.listar(), await _vehiculos.listar()));
    if (datos == null) return;
    final (rutas, flota) = datos;
    _lista = rutas;
    _flota = flota;
    if (_seleccionada != null) {
      _seleccionada = _lista.where((r) => r.id == _seleccionada!.id).firstOrNull;
    }
    notificar();
  }

  Future<void> seleccionar(Ruta ruta) async {
    _seleccionada = ruta;
    _salidas = const [];
    notificar();
    final salidas = await ejecutar(() => _rutas.salidas(ruta.id));
    if (salidas != null) {
      _salidas = salidas;
      notificar();
    }
  }

  Future<bool> guardar(Ruta ruta) async {
    final guardada = await ejecutar(() => ruta.id == 0 ? _rutas.crear(ruta) : _rutas.actualizar(ruta));
    if (guardada == null) return false;
    _lista = _reemplazar(_lista, guardada, (r) => r.id);
    notificar();
    return true;
  }

  Future<bool> agregarSalida(int hora, {int? duracionMin}) async {
    final ruta = _seleccionada;
    if (ruta == null) return false;
    final salida = await ejecutar(() => _rutas.crearSalida(ruta.id, hora, duracionMin: duracionMin));
    if (salida == null) return false;
    _salidas = [..._salidas, salida]..sort((a, b) => a.hora.compareTo(b.hora));
    notificar();
    return true;
  }

  Future<bool> eliminarSalida(SalidaAutorizada salida) async {
    final hecho = await ejecutar(() async {
      await _rutas.eliminarSalida(salida.id);
      return true;
    });
    if (hecho == null) return false;
    _salidas = [for (final s in _salidas) if (s.id != salida.id) s];
    notificar();
    return true;
  }
}

/// HU-06.
class ServiciosControlador extends ControladorBase {
  ServiciosControlador(this._servicios, this._rutas, {DateTime? hoy})
      : _fecha = _manana(hoy ?? DateTime.now());

  final RepositorioServicios _servicios;
  final RepositorioRutas _rutas;

  DateTime _fecha;
  List<ServicioProgramado> _lista = const [];
  List<Ruta> _rutasActivas = const [];
  final Map<int, List<SalidaAutorizada>> _salidas = {};

  static DateTime _manana(DateTime hoy) => DateTime.utc(hoy.year, hoy.month, hoy.day + 1);

  /// Turno que se está registrando; por defecto, el día siguiente.
  DateTime get fecha => _fecha;
  List<ServicioProgramado> get servicios => _lista;
  List<Ruta> get rutas => _rutasActivas;
  List<SalidaAutorizada> salidasDe(int rutaId) => _salidas[rutaId] ?? const [];

  Future<void> cargar() async {
    final datos = await ejecutar(() async => (await _servicios.listar(_fecha), await _rutas.listar()));
    if (datos == null) return;
    _lista = datos.$1;
    _rutasActivas = [for (final r in datos.$2) if (r.activa) r];
    notificar();
  }

  Future<void> cambiarFecha(DateTime fecha) async {
    _fecha = DateTime.utc(fecha.year, fecha.month, fecha.day);
    await cargar();
  }

  /// Salidas autorizadas de la ruta, para ofrecer solo horas permitidas
  /// (HU-05).
  Future<void> cargarSalidas(int rutaId) async {
    if (_salidas.containsKey(rutaId)) return;
    final salidas = await ejecutar(() => _rutas.salidas(rutaId));
    if (salidas != null) {
      _salidas[rutaId] = salidas;
      notificar();
    }
  }

  Future<bool> guardar(ServicioProgramado servicio) async {
    final guardado = await ejecutar(
      () => servicio.id == 0 ? _servicios.crear(servicio) : _servicios.actualizar(servicio),
    );
    if (guardado == null) return false;
    if (guardado.fecha == _fecha) _lista = _reemplazar(_lista, guardado, (s) => s.id);
    notificar();
    return true;
  }

  Future<bool> cancelar(ServicioProgramado servicio) async {
    final cancelado = await ejecutar(() => _servicios.cancelar(servicio.id));
    if (cancelado == null) return false;
    _lista = _reemplazar(_lista, cancelado, (s) => s.id);
    notificar();
    return true;
  }
}

/// HU-01 (administración de usuarios).
class UsuariosControlador extends ControladorBase {
  UsuariosControlador(this._repositorio);

  final RepositorioUsuarios _repositorio;

  List<Usuario> _usuarios = const [];
  List<Usuario> get usuarios => _usuarios;

  Future<void> cargar() async {
    final lista = await ejecutar(_repositorio.listar);
    if (lista != null) {
      _usuarios = lista;
      notificar();
    }
  }

  Future<bool> crear(SolicitudUsuario solicitud) async {
    final creado = await ejecutar(() => _repositorio.crear(solicitud));
    if (creado == null) return false;
    _usuarios = _reemplazar(_usuarios, creado, (u) => u.id);
    notificar();
    return true;
  }
}
