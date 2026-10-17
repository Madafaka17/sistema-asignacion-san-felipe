import 'package:dominio/dominio.dart';

import '../api/api_cliente.dart';

abstract interface class RepositorioProgramaciones {
  /// HU-07: puede tardar hasta `t_lím`; usa un tiempo de espera mayor.
  Future<Programacion> generar(DateTime fecha);
  Future<List<Programacion>> listar(DateTime fecha);
  Future<Programacion> obtener(int id);
  Future<Programacion> ajustar(int programacionId, int servicioId, AjusteAsignacion ajuste);
  Future<Programacion> aprobar(int id);
}

abstract interface class RepositorioIncidencias {
  Future<List<Incidencia>> listar({DateTime? desde, DateTime? hasta});
  Future<Incidencia> registrar(SolicitudIncidencia solicitud);
}

abstract interface class RepositorioReportes {
  Future<ReporteIndicadores> indicadores(DateTime desde, DateTime hasta);
  Future<String> csv(DateTime desde, DateTime hasta);
}

abstract interface class RepositorioAdministracion {
  Future<Pagina<EntradaBitacora>> bitacora({int pagina = 1, String? accion});
  Future<Map<String, Object?>> parametros();
}

Map<String, Object?> _mapa(Object? json) => json as Map<String, Object?>;

class RepositorioProgramacionesApi implements RepositorioProgramaciones {
  const RepositorioProgramacionesApi(this._api);

  final ApiCliente _api;

  @override
  Future<Programacion> generar(DateTime fecha) async => Programacion.fromJson(
        _mapa(await _api.post('/programaciones', SolicitudProgramacion(fecha: fecha).toJson(), ApiCliente.limiteGeneracion)),
      );

  @override
  Future<List<Programacion>> listar(DateTime fecha) async => [
        for (final p in await _api.get('/programaciones', consulta: {'fecha': fechaATexto(fecha)}) as List<Object?>)
          Programacion.fromJson(_mapa(p)),
      ];

  @override
  Future<Programacion> obtener(int id) async => Programacion.fromJson(_mapa(await _api.get('/programaciones/$id')));

  @override
  Future<Programacion> ajustar(int programacionId, int servicioId, AjusteAsignacion ajuste) async =>
      Programacion.fromJson(
        _mapa(await _api.put('/programaciones/$programacionId/asignaciones/$servicioId', ajuste.toJson())),
      );

  @override
  Future<Programacion> aprobar(int id) async =>
      Programacion.fromJson(_mapa(await _api.post('/programaciones/$id/aprobar')));
}

class RepositorioIncidenciasApi implements RepositorioIncidencias {
  const RepositorioIncidenciasApi(this._api);

  final ApiCliente _api;

  @override
  Future<List<Incidencia>> listar({DateTime? desde, DateTime? hasta}) async => Pagina.fromJson(
        _mapa(await _api.get('/incidencias', consulta: {
          'tamano': '200',
          if (desde != null) 'desde': fechaATexto(desde),
          if (hasta != null) 'hasta': fechaATexto(hasta),
        })),
        Incidencia.fromJson,
      ).elementos;

  @override
  Future<Incidencia> registrar(SolicitudIncidencia solicitud) async =>
      Incidencia.fromJson(_mapa(await _api.post('/incidencias', solicitud.toJson())));
}

class RepositorioReportesApi implements RepositorioReportes {
  const RepositorioReportesApi(this._api);

  final ApiCliente _api;

  Map<String, String> _periodo(DateTime desde, DateTime hasta) =>
      {'desde': fechaATexto(desde), 'hasta': fechaATexto(hasta)};

  @override
  Future<ReporteIndicadores> indicadores(DateTime desde, DateTime hasta) async =>
      ReporteIndicadores.fromJson(_mapa(await _api.get('/reportes/indicadores', consulta: _periodo(desde, hasta))));

  @override
  Future<String> csv(DateTime desde, DateTime hasta) =>
      _api.texto('/reportes/indicadores.csv', consulta: _periodo(desde, hasta));
}

class RepositorioAdministracionApi implements RepositorioAdministracion {
  const RepositorioAdministracionApi(this._api);

  final ApiCliente _api;

  @override
  Future<Pagina<EntradaBitacora>> bitacora({int pagina = 1, String? accion}) async => Pagina.fromJson(
        _mapa(await _api.get('/bitacora', consulta: {
          'pagina': '$pagina',
          'tamano': '50',
          if (accion != null && accion.isNotEmpty) 'accion': accion,
        })),
        EntradaBitacora.fromJson,
      );

  @override
  Future<Map<String, Object?>> parametros() async => _mapa(await _api.get('/parametros'));
}
