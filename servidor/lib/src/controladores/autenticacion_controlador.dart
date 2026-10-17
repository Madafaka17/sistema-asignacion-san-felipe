import 'package:dominio/dominio.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/http_util.dart';
import '../infraestructura/base_datos.dart';
import '../servicios/autenticacion_servicio.dart';

/// `/api/auth/*`, `/api/version` y `/api/salud`.
class AutenticacionControlador {
  AutenticacionControlador(this._servicio, this._bd, {required this.cookieSegura, required this.versionServidor});

  final AutenticacionServicio _servicio;
  final BaseDatos _bd;
  final bool cookieSegura;
  final String versionServidor;

  static const nombreCookie = 'refresco';
  static const rutaCookie = '/api/auth';
  static const rutasPublicas = {
    '/api/auth/ingresar',
    '/api/auth/refrescar',
    '/api/auth/salir',
    '/api/version',
    '/api/salud',
  };

  void registrar(Router r) {
    r.post('/api/auth/ingresar', _ingresar);
    r.post('/api/auth/refrescar', _refrescar);
    r.post('/api/auth/salir', _salir);
    r.get('/api/version', _version);
    r.get('/api/salud', _salud);
  }

  Future<Response> _ingresar(Request solicitud) async {
    final l = LectorJson(await leerJson(solicitud));
    final usuario = l.texto('nombreUsuario', maximo: 50);
    final contrasena = l.texto('contrasena', maximo: 128);
    l.verificar();
    return _conCookie(await _servicio.ingresar(usuario, contrasena));
  }

  Future<Response> _refrescar(Request solicitud) async =>
      _conCookie(await _servicio.refrescar(cookie(solicitud, nombreCookie)));

  Future<Response> _salir(Request solicitud) async {
    await _servicio.salir(cookie(solicitud, nombreCookie));
    return Response(204, headers: {'set-cookie': _cabeceraCookie('', Duration.zero)});
  }

  Response _version(Request solicitud) =>
      respuestaJson(InfoVersion(versionApi: versionApi, versionServidor: versionServidor).toJson());

  Future<Response> _salud(Request solicitud) async {
    try {
      await _bd.consultar('SELECT 1');
      return respuestaJson({'estado': 'ok', 'baseDatos': 'ok'});
    } catch (_) {
      return respuestaJson({'estado': 'degradado', 'baseDatos': 'sin conexión'}, estado: 503);
    }
  }

  Response _conCookie(SesionEmitida emitida) => respuestaJson(
        emitida.sesion.toJson(),
        cabeceras: {'set-cookie': _cabeceraCookie(emitida.tokenActualizacion, emitida.duracionActualizacion)},
      );

  /// Token de actualización en una cookie `HttpOnly` (inaccesible desde
  /// JavaScript), `SameSite=Strict` y, con HTTPS, `Secure`.
  String _cabeceraCookie(String valor, Duration duracion) => [
        '$nombreCookie=$valor',
        'Path=$rutaCookie',
        'Max-Age=${duracion.inSeconds}',
        'HttpOnly',
        'SameSite=Strict',
        if (cookieSegura) 'Secure',
      ].join('; ');
}
