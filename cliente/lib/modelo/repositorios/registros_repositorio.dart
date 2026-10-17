import 'package:dominio/dominio.dart';

import '../api/api_cliente.dart';

/// Repositorios remotos (capa Modelo): los controladores dependen de estas
/// interfaces y nunca hacen HTTP ni conocen las rutas de la API. En las
/// pruebas de los controladores se sustituyen por dobles en memoria.
abstract interface class RepositorioVehiculos {
  Future<List<Vehiculo>> listar();
  Future<Vehiculo> crear(Vehiculo vehiculo);
  Future<Vehiculo> actualizar(Vehiculo vehiculo);

  /// `chab(v)` y `C_v^R` de todas las unidades.
  Future<List<ParAutorizado>> pares();
  Future<ConductoresAutorizados> asignarConductores(ConductoresAutorizados autorizados);
}

abstract interface class RepositorioConductores {
  Future<List<Conductor>> listar();
  Future<Conductor> crear(Conductor conductor);
  Future<Conductor> actualizar(Conductor conductor);
  Future<Conductor> cambiarDisponibilidad(int id, bool disponible);
}

abstract interface class RepositorioRutas {
  Future<List<Ruta>> listar();
  Future<Ruta> crear(Ruta ruta);
  Future<Ruta> actualizar(Ruta ruta);
  Future<List<SalidaAutorizada>> salidas(int rutaId);
  Future<SalidaAutorizada> crearSalida(int rutaId, int hora, {int? duracionMin});
  Future<void> eliminarSalida(int id);
}

abstract interface class RepositorioServicios {
  Future<List<ServicioProgramado>> listar(DateTime fecha);
  Future<ServicioProgramado> crear(ServicioProgramado servicio);
  Future<ServicioProgramado> actualizar(ServicioProgramado servicio);
  Future<ServicioProgramado> cancelar(int id);
}

/// Cola de despacho de cada ruta y fecha (sección 3.1.2).
abstract interface class RepositorioCola {
  Future<List<EntradaCola>> entradas(DateTime fecha, {int? rutaId});
  Future<EntradaCola> registrar(SolicitudEntradaCola solicitud);
  Future<EntradaCola> retirar(int id);
}

abstract interface class RepositorioUsuarios {
  Future<List<Usuario>> listar();
  Future<Usuario> crear(SolicitudUsuario solicitud);
}

Map<String, Object?> _mapa(Object? json) => json as Map<String, Object?>;

List<T> _elementos<T>(Object? json, T Function(Map<String, Object?>) desdeJson) =>
    Pagina.fromJson(_mapa(json), desdeJson).elementos;

List<T> _lista<T>(Object? json, T Function(Object?) desdeJson) => [for (final e in json as List<Object?>) desdeJson(e)];

const _todos = {'tamano': '200'};

class RepositorioVehiculosApi implements RepositorioVehiculos {
  const RepositorioVehiculosApi(this._api);

  final ApiCliente _api;

  @override
  Future<List<Vehiculo>> listar() async => _elementos(await _api.get('/vehiculos', consulta: _todos), Vehiculo.fromJson);

  @override
  Future<Vehiculo> crear(Vehiculo vehiculo) async =>
      Vehiculo.fromJson(await _api.post('/vehiculos', vehiculo.toJson()..remove('id')));

  @override
  Future<Vehiculo> actualizar(Vehiculo vehiculo) async =>
      Vehiculo.fromJson(await _api.put('/vehiculos/${vehiculo.id}', vehiculo.toJson()));

  @override
  Future<List<ParAutorizado>> pares() async => _lista(await _api.get('/pares'), ParAutorizado.fromJson);

  @override
  Future<ConductoresAutorizados> asignarConductores(ConductoresAutorizados a) async => ConductoresAutorizados.fromJson(
        await _api.put('/vehiculos/${a.vehiculoId}/conductores', a.toJson()..remove('vehiculoId')),
      );
}

class RepositorioConductoresApi implements RepositorioConductores {
  const RepositorioConductoresApi(this._api);

  final ApiCliente _api;

  @override
  Future<List<Conductor>> listar() async =>
      _elementos(await _api.get('/conductores', consulta: _todos), Conductor.fromJson);

  @override
  Future<Conductor> crear(Conductor conductor) async =>
      Conductor.fromJson(await _api.post('/conductores', conductor.toJson()..remove('id')));

  @override
  Future<Conductor> actualizar(Conductor conductor) async =>
      Conductor.fromJson(await _api.put('/conductores/${conductor.id}', conductor.toJson()));

  @override
  Future<Conductor> cambiarDisponibilidad(int id, bool disponible) async =>
      Conductor.fromJson(await _api.put('/conductores/$id/disponibilidad', {'disponible': disponible}));
}

class RepositorioRutasApi implements RepositorioRutas {
  const RepositorioRutasApi(this._api);

  final ApiCliente _api;

  @override
  Future<List<Ruta>> listar() async => _lista(await _api.get('/rutas'), Ruta.fromJson);

  @override
  Future<Ruta> crear(Ruta ruta) async => Ruta.fromJson(await _api.post('/rutas', ruta.toJson()..remove('id')));

  @override
  Future<Ruta> actualizar(Ruta ruta) async => Ruta.fromJson(await _api.put('/rutas/${ruta.id}', ruta.toJson()));

  @override
  Future<List<SalidaAutorizada>> salidas(int rutaId) async =>
      _lista(await _api.get('/rutas/$rutaId/salidas'), SalidaAutorizada.fromJson);

  @override
  Future<SalidaAutorizada> crearSalida(int rutaId, int hora, {int? duracionMin}) async => SalidaAutorizada.fromJson(
        await _api.post('/rutas/$rutaId/salidas', {'hora': hora, 'duracionMin': duracionMin}),
      );

  @override
  Future<void> eliminarSalida(int id) => _api.delete('/salidas/$id');
}

class RepositorioServiciosApi implements RepositorioServicios {
  const RepositorioServiciosApi(this._api);

  final ApiCliente _api;

  @override
  Future<List<ServicioProgramado>> listar(DateTime fecha) async => _elementos(
        await _api.get('/servicios', consulta: {..._todos, 'fecha': fechaATexto(fecha)}),
        ServicioProgramado.fromJson,
      );

  @override
  Future<ServicioProgramado> crear(ServicioProgramado servicio) async =>
      ServicioProgramado.fromJson(await _api.post('/servicios', servicio.toJsonSolicitud()));

  @override
  Future<ServicioProgramado> actualizar(ServicioProgramado servicio) async =>
      ServicioProgramado.fromJson(await _api.put('/servicios/${servicio.id}', servicio.toJsonSolicitud()));

  @override
  Future<ServicioProgramado> cancelar(int id) async =>
      ServicioProgramado.fromJson(await _api.post('/servicios/$id/cancelar'));
}

class RepositorioColaApi implements RepositorioCola {
  const RepositorioColaApi(this._api);

  final ApiCliente _api;

  @override
  Future<List<EntradaCola>> entradas(DateTime fecha, {int? rutaId}) async => _lista(
        await _api.get('/cola', consulta: {'fecha': fechaATexto(fecha), if (rutaId != null) 'rutaId': '$rutaId'}),
        EntradaCola.fromJson,
      );

  @override
  Future<EntradaCola> registrar(SolicitudEntradaCola solicitud) async =>
      EntradaCola.fromJson(await _api.post('/cola', solicitud.toJson()));

  @override
  Future<EntradaCola> retirar(int id) async => EntradaCola.fromJson(await _api.post('/cola/$id/retirar'));
}

class RepositorioUsuariosApi implements RepositorioUsuarios {
  const RepositorioUsuariosApi(this._api);

  final ApiCliente _api;

  @override
  Future<List<Usuario>> listar() async => _elementos(await _api.get('/usuarios', consulta: _todos), Usuario.fromJson);

  @override
  Future<Usuario> crear(SolicitudUsuario solicitud) async =>
      Usuario.fromJson(_mapa(await _api.post('/usuarios', solicitud.toJson())));
}
