import 'dart:async';
import 'dart:convert';

import 'package:dominio/dominio.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Solicitud registrada por el servidor simulado.
class SolicitudRegistrada {
  SolicitudRegistrada(this.metodo, this.ruta, this.cabeceras, this.cuerpo);

  final String metodo;
  final String ruta;
  final Map<String, String> cabeceras;
  final Object? cuerpo;

  @override
  String toString() => '$metodo $ruta';
}

typedef Manejador = FutureOr<http.Response> Function(http.Request solicitud);

/// Servidor HTTP en memoria con las respuestas del contrato, para probar el
/// cliente sin red. Registra cada solicitud para verificar el payload.
class ServidorSimulado {
  final solicitudes = <SolicitudRegistrada>[];
  final _manejadores = <String, Manejador>{};

  void en(String metodo, String ruta, Manejador manejador) => _manejadores['$metodo $ruta'] = manejador;

  late final cliente = MockClient((solicitud) async {
    final ruta = solicitud.url.path;
    solicitudes.add(SolicitudRegistrada(
      solicitud.method,
      ruta,
      solicitud.headers,
      solicitud.body.isEmpty ? null : jsonDecode(solicitud.body),
    ));
    final manejador = _manejadores['${solicitud.method} $ruta'];
    if (manejador == null) {
      return json(ExcepcionApi(CodigoError.noEncontrado, 'Sin simulación para ${solicitud.method} $ruta').toJson(), 404);
    }
    return manejador(solicitud);
  });

  Iterable<SolicitudRegistrada> de(String metodo, String ruta) =>
      solicitudes.where((s) => s.metodo == metodo && s.ruta == ruta);

  static http.Response json(Object? cuerpo, [int estado = 200, Map<String, String> cabeceras = const {}]) => http.Response(
        jsonEncode(cuerpo),
        estado,
        headers: {'content-type': 'application/json; charset=utf-8', 'x-version-api': versionApi, ...cabeceras},
      );

  /// Versión, sesión inexistente al iniciar e ingreso de [usuario].
  void conSesion(Usuario usuario) {
    en('GET', '/api/version', (_) => json(const InfoVersion(versionApi: versionApi, versionServidor: '1.0.0').toJson()));
    en('POST', '/api/auth/refrescar', (_) => json(ExcepcionApi(CodigoError.noAutenticado, 'Sin sesión').toJson(), 401));
    en('POST', '/api/auth/ingresar', (s) {
      final datos = jsonDecode(s.body) as Map<String, Object?>;
      if (datos['contrasena'] != 'Despacho2026') {
        return json(ExcepcionApi(CodigoError.noAutenticado, 'Usuario o contraseña incorrectos').toJson(), 401);
      }
      return json(
        SesionIniciada(tokenAcceso: 'token-de-prueba', expiraEnSegundos: 900, usuario: usuario).toJson(),
        200,
        {'set-cookie': 'refresco=abc; Path=/api/auth; HttpOnly; SameSite=Strict'},
      );
    });
  }
}

const usuarioDespacho = Usuario(
  id: 3,
  nombreUsuario: 'jdespacho',
  nombreCompleto: 'Personal de despacho',
  rol: Rol.despacho,
);
