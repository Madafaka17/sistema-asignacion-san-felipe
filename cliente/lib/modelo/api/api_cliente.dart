import 'dart:async';
import 'dart:convert';

import 'package:dominio/dominio.dart';
import 'package:http/http.dart' as http;

import '../../configuracion.dart';
import 'cliente_http.dart';

/// Error de red o de tiempo de espera (no hubo respuesta del servidor).
class ErrorConexion implements Exception {
  const ErrorConexion(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Único punto de acceso HTTP del cliente (capa Modelo del MVC).
///
/// * Añade `Authorization: Bearer` con el token de acceso, que solo vive en
///   memoria (nunca en `localStorage`).
/// * Ante un 401 renueva una vez el token con la cookie del token de
///   actualización y repite la solicitud; si no puede, purga la sesión y
///   avisa con [alExpirarSesion].
/// * Envía `X-Version-Cliente` y comprueba `X-Version-Api` en cada
///   respuesta para mantener la compatibilidad cliente–servidor.
/// * Convierte las respuestas de error del contrato en [ExcepcionApi].
class ApiCliente {
  ApiCliente({required Uri base, http.Client? cliente, this.limite = const Duration(seconds: 30)})
      : _base = base.path.endsWith('/') ? base.replace(path: base.path.substring(0, base.path.length - 1)) : base,
        _http = cliente ?? crearClienteHttp(),
        _cookiesManuales = gestionaCookiesManualmente;

  final Uri _base;
  final http.Client _http;
  final bool _cookiesManuales;

  /// Tiempo de espera de las solicitudes comunes.
  final Duration limite;

  /// La generación de la programación puede tardar hasta `t_lím` = 300 s
  /// (RNF-02); el cliente espera un poco más.
  static const limiteGeneracion = Duration(seconds: 320);

  static const _rutasAutenticacion = {'/auth/ingresar', '/auth/refrescar', '/auth/salir'};

  String? _tokenAcceso;

  /// Token de actualización (solo escritorio; en la web lo guarda el
  /// navegador en una cookie `HttpOnly`).
  String? _cookieActualizacion;
  Future<bool>? _renovacionEnCurso;

  /// Se invoca cuando la sesión no se pudo renovar.
  void Function()? alExpirarSesion;

  bool get tieneSesion => _tokenAcceso != null;

  // --- Sesión -----------------------------------------------------------

  Future<InfoVersion> version() async {
    final info = InfoVersion.fromJson(await get('/version') as Map<String, Object?>);
    if (!versionesCompatibles(info.versionApi, versionCliente)) {
      throw ExcepcionApi(
        CodigoError.versionIncompatible,
        'El servidor usa la API ${info.versionApi} y este cliente la $versionCliente; actualice la aplicación',
      );
    }
    return info;
  }

  Future<SesionIniciada> ingresar(String nombreUsuario, String contrasena) async {
    final json = await post('/auth/ingresar', {'nombreUsuario': nombreUsuario, 'contrasena': contrasena});
    final sesion = SesionIniciada.fromJson(json as Map<String, Object?>);
    _tokenAcceso = sesion.tokenAcceso;
    return sesion;
  }

  /// Intenta recuperar la sesión con el token de actualización (por
  /// ejemplo, al recargar la página web). Devuelve `null` si no hay sesión.
  Future<SesionIniciada?> reanudar() async {
    try {
      final json = await post('/auth/refrescar');
      final sesion = SesionIniciada.fromJson(json as Map<String, Object?>);
      _tokenAcceso = sesion.tokenAcceso;
      return sesion;
    } on ExcepcionApi catch (e) {
      if (e.codigo == CodigoError.noAutenticado) return null;
      rethrow;
    }
  }

  Future<void> salir() async {
    try {
      await post('/auth/salir');
    } finally {
      purgarSesion();
    }
  }

  void purgarSesion() {
    _tokenAcceso = null;
    _cookieActualizacion = null;
  }

  // --- Verbos -----------------------------------------------------------

  Future<Object?> get(String ruta, {Map<String, String>? consulta}) => _json('GET', ruta, consulta: consulta);

  Future<Object?> post(String ruta, [Object? cuerpo, Duration? limite]) =>
      _json('POST', ruta, cuerpo: cuerpo, limite: limite);

  Future<Object?> put(String ruta, Object? cuerpo) => _json('PUT', ruta, cuerpo: cuerpo);

  Future<void> delete(String ruta) => _json('DELETE', ruta);

  /// Respuesta de texto (exportación CSV).
  Future<String> texto(String ruta, {Map<String, String>? consulta}) async =>
      utf8.decode((await _enviar('GET', ruta, consulta: consulta)).bodyBytes);

  // --- Implementación -----------------------------------------------------

  Future<Object?> _json(String metodo, String ruta, {Map<String, String>? consulta, Object? cuerpo, Duration? limite}) async {
    final respuesta = await _enviar(metodo, ruta, consulta: consulta, cuerpo: cuerpo, limite: limite);
    if (respuesta.statusCode == 204 || respuesta.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(respuesta.bodyBytes));
  }

  Future<http.Response> _enviar(
    String metodo,
    String ruta, {
    Map<String, String>? consulta,
    Object? cuerpo,
    Duration? limite,
    bool reintento = false,
  }) async {
    final respuesta = await _una(metodo, ruta, consulta: consulta, cuerpo: cuerpo, limite: limite);
    if (respuesta.statusCode == 401 && !_rutasAutenticacion.contains(ruta) && !reintento) {
      if (await _renovar()) {
        return _enviar(metodo, ruta, consulta: consulta, cuerpo: cuerpo, limite: limite, reintento: true);
      }
      purgarSesion();
      alExpirarSesion?.call();
    }
    if (respuesta.statusCode >= 400) throw _error(respuesta);
    return respuesta;
  }

  Future<http.Response> _una(String metodo, String ruta, {Map<String, String>? consulta, Object? cuerpo, Duration? limite}) async {
    final uri = _base.replace(
      path: '${_base.path}$ruta',
      queryParameters: consulta == null || consulta.isEmpty ? null : consulta,
    );
    final solicitud = http.Request(metodo, uri)
      ..headers.addAll({
        'accept': 'application/json',
        'x-version-cliente': versionCliente,
        if (_tokenAcceso != null) 'authorization': 'Bearer $_tokenAcceso',
        if (_cookiesManuales && _cookieActualizacion != null && ruta.startsWith('/auth/'))
          'cookie': 'refresco=$_cookieActualizacion',
      });
    if (cuerpo != null) {
      solicitud
        ..headers['content-type'] = 'application/json; charset=utf-8'
        ..body = jsonEncode(cuerpo);
    }
    final http.Response respuesta;
    try {
      respuesta = await http.Response.fromStream(await _http.send(solicitud).timeout(limite ?? this.limite));
    } on TimeoutException {
      throw const ErrorConexion('El servidor no respondió a tiempo. Intente nuevamente.');
    } on http.ClientException {
      throw const ErrorConexion('No se pudo conectar con el servidor. Revise la conexión.');
    }
    if (_cookiesManuales) _guardarCookie(respuesta.headers['set-cookie']);
    final versionServidor = respuesta.headers['x-version-api'];
    if (versionServidor != null && !versionesCompatibles(versionServidor, versionCliente)) {
      throw ExcepcionApi(
        CodigoError.versionIncompatible,
        'El servidor usa la API $versionServidor y este cliente la $versionCliente; actualice la aplicación',
      );
    }
    return respuesta;
  }

  /// Renueva el token de acceso una sola vez aunque varias solicitudes
  /// reciban 401 a la vez.
  Future<bool> _renovar() => _renovacionEnCurso ??= () async {
        try {
          final respuesta = await _una('POST', '/auth/refrescar');
          if (respuesta.statusCode != 200) return false;
          final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, Object?>;
          _tokenAcceso = SesionIniciada.fromJson(json).tokenAcceso;
          return true;
        } on Object {
          return false;
        } finally {
          _renovacionEnCurso = null;
        }
      }();

  static final _patronCookie = RegExp(r'(?:^|,\s*)refresco=([^;,]*)');

  void _guardarCookie(String? cabecera) {
    if (cabecera == null) return;
    final coincidencia = _patronCookie.firstMatch(cabecera);
    if (coincidencia == null) return;
    final valor = coincidencia.group(1)!;
    _cookieActualizacion = valor.isEmpty || cabecera.contains('Max-Age=0') ? null : valor;
  }

  Exception _error(http.Response respuesta) {
    try {
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (json is Map<String, Object?> && json['error'] is Map) return ExcepcionApi.fromJson(json);
    } on FormatException {
      // Respuesta que no es del contrato (por ejemplo, un proxy caído).
    }
    return ExcepcionApi(CodigoError.interno, 'Error ${respuesta.statusCode} del servidor');
  }
}
