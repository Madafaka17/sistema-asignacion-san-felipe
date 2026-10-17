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

/// HU-02 y conductores autorizados de cada unidad (sección 3.1.2).
class VehiculosControlador extends ControladorBase {
  VehiculosControlador(this._repositorio, this._conductores);

  final RepositorioVehiculos _repositorio;
  final RepositorioConductores _conductores;

  List<Vehiculo> _vehiculos = const [];
  List<Conductor> _plantilla = const [];
  Map<int, ConductoresAutorizados> _autorizados = const {};

  List<Vehiculo> get vehiculos => _vehiculos;
  List<Conductor> get conductores => _plantilla;

  /// `chab(v)` y `C_v^R` de la unidad.
  ConductoresAutorizados autorizadosDe(int vehiculoId) =>
      _autorizados[vehiculoId] ?? ConductoresAutorizados(vehiculoId: vehiculoId);

  String codigoConductor(int id) => _plantilla.where((c) => c.id == id).firstOrNull?.codigo ?? '$id';

  Future<void> cargar() async {
    final datos = await ejecutar(() async => (await _repositorio.listar(), await _conductores.listar(), await _repositorio.pares()));
    if (datos == null) return;
    final (vehiculos, plantilla, pares) = datos;
    _vehiculos = vehiculos;
    _plantilla = plantilla;
    _autorizados = ConductoresAutorizados.porVehiculo(pares);
    notificar();
  }

  Future<bool> asignarConductores(ConductoresAutorizados autorizados) async {
    final guardado = await ejecutar(() => _repositorio.asignarConductores(autorizados));
    if (guardado == null) return false;
    _autorizados = {..._autorizados, guardado.vehiculoId: guardado};
    notificar();
    return true;
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
  ServiciosControlador(this._servicios, this._rutas, this._cola, {DateTime? hoy})
      : _fecha = _manana(hoy ?? DateTime.now());

  final RepositorioServicios _servicios;
  final RepositorioRutas _rutas;
  final RepositorioCola _cola;

  DateTime _fecha;
  List<ServicioProgramado> _lista = const [];
  List<Ruta> _rutasActivas = const [];
  final Map<int, List<SalidaAutorizada>> _salidas = {};
  final Map<int, List<EntradaCola>> _entradas = {};

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
    _entradas.clear();
    await cargar();
  }

  /// Turnos de la cola de la ruta en la fecha que pueden corresponder a un
  /// servicio que sale a la [hora]: la unidad sigue en la cola, llegó antes
  /// y su turno no es de otro servicio. Están en orden de llegada, así que el
  /// primero es la unidad que corresponde (`v0(s)`).
  List<EntradaCola> turnosDisponibles(int rutaId, int hora, {int? servicioId}) => [
        for (final e in _entradas[rutaId] ?? const <EntradaCola>[])
          if (e.activa && e.llegada <= hora && (e.servicioId == null || e.servicioId == servicioId)) e,
      ];

  /// Salidas autorizadas (HU-05) y cola de la ruta, para ofrecer solo
  /// horas permitidas y turnos de la cola. Con [forzar] se vuelve a pedir la
  /// cola, por ejemplo después de que un servicio tomó un turno.
  Future<void> cargarRuta(int rutaId, {bool forzar = false}) async {
    final pedirSalidas = !_salidas.containsKey(rutaId);
    final pedirCola = forzar || !_entradas.containsKey(rutaId);
    if (!pedirSalidas && !pedirCola) return;
    final datos = await ejecutar(() async => (
          pedirSalidas ? await _rutas.salidas(rutaId) : _salidas[rutaId]!,
          pedirCola ? await _cola.entradas(_fecha, rutaId: rutaId) : _entradas[rutaId]!,
        ));
    if (datos != null) {
      _salidas[rutaId] = datos.$1;
      _entradas[rutaId] = datos.$2;
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
    // El turno tomado deja de estar disponible.
    if (_entradas.containsKey(guardado.rutaId)) await cargarRuta(guardado.rutaId, forzar: true);
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

/// Cola de despacho de cada ruta (sección 3.1.2): llegadas al terminal y
/// retiro de unidades.
class ColaControlador extends ControladorBase {
  ColaControlador(this._cola, this._rutas, this._vehiculos, {DateTime? hoy})
      : _fecha = ServiciosControlador._manana(hoy ?? DateTime.now());

  final RepositorioCola _cola;
  final RepositorioRutas _rutas;
  final RepositorioVehiculos _vehiculos;

  DateTime _fecha;
  List<Ruta> _rutasActivas = const [];
  List<Vehiculo> _flota = const [];
  int? _rutaId;
  List<EntradaCola> _entradas = const [];

  DateTime get fecha => _fecha;
  List<Ruta> get rutas => _rutasActivas;
  Ruta? get ruta => _rutasActivas.where((r) => r.id == _rutaId).firstOrNull;

  /// Entradas de la ruta elegida, por orden de llegada.
  List<EntradaCola> get entradas => _entradas;

  int get enEspera => _entradas.where((e) => e.libre).length;

  /// Unidades operativas compatibles con la ruta elegida.
  List<Vehiculo> get unidadesElegibles => [
        for (final v in _flota)
          if (v.disponible && (ruta?.vehiculosCompatibles.contains(v.id) ?? false)) v,
      ];

  Future<void> cargar() async {
    final datos = await ejecutar(() async => (await _rutas.listar(), await _vehiculos.listar()));
    if (datos == null) return;
    _rutasActivas = [for (final r in datos.$1) if (r.activa) r];
    _flota = datos.$2;
    if (ruta == null) _rutaId = _rutasActivas.firstOrNull?.id;
    await _cargarEntradas();
  }

  Future<void> cambiarFecha(DateTime fecha) async {
    _fecha = DateTime.utc(fecha.year, fecha.month, fecha.day);
    await _cargarEntradas();
  }

  Future<void> seleccionarRuta(int rutaId) async {
    _rutaId = rutaId;
    _entradas = const [];
    notificar();
    await _cargarEntradas();
  }

  Future<void> _cargarEntradas() async {
    final rutaId = _rutaId;
    if (rutaId == null) {
      notificar();
      return;
    }
    final entradas = await ejecutar(() => _cola.entradas(_fecha, rutaId: rutaId));
    if (entradas != null) {
      _entradas = entradas;
      notificar();
    }
  }

  Future<bool> registrarLlegada(int vehiculoId, int llegada) async {
    final rutaId = _rutaId;
    if (rutaId == null) return false;
    final entrada = await ejecutar(() => _cola.registrar(
          SolicitudEntradaCola(rutaId: rutaId, fecha: _fecha, vehiculoId: vehiculoId, llegada: llegada),
        ));
    if (entrada == null) return false;
    _entradas = [..._entradas, entrada];
    notificar();
    return true;
  }

  Future<bool> retirar(EntradaCola entrada) async {
    final retirada = await ejecutar(() => _cola.retirar(entrada.id));
    if (retirada == null) return false;
    _entradas = _reemplazar(_entradas, retirada, (e) => e.id);
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
