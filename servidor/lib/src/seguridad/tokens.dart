import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dominio/dominio.dart';

/// Usuario autenticado que viaja en el contexto de cada solicitud.
class UsuarioAutenticado {
  const UsuarioAutenticado({required this.id, required this.nombreUsuario, required this.rol});

  final int id;
  final String nombreUsuario;
  final Rol rol;
}

/// Emisión y verificación de tokens.
///
/// * Token de acceso: JWT HS256 de corta duración; el cliente lo guarda solo
///   en memoria y lo envía en `Authorization: Bearer`.
/// * Token de actualización: 32 bytes aleatorios en una cookie `HttpOnly`;
///   en la base de datos se guarda solo su resumen SHA-256.
class Tokens {
  Tokens({required String secreto, required this.duracionAcceso})
      : _clave = SecretKey(secreto);

  static const emisor = 'sistema-asignacion-san-felipe';

  final SecretKey _clave;
  final Duration duracionAcceso;

  String emitirAcceso(UsuarioAutenticado usuario) => JWT(
        {'nombre': usuario.nombreUsuario, 'rol': usuario.rol.valor},
        subject: usuario.id.toString(),
        issuer: emisor,
      ).sign(_clave, algorithm: JWTAlgorithm.HS256, expiresIn: duracionAcceso);

  /// Devuelve el usuario del token o `null` si no es válido o expiró.
  UsuarioAutenticado? verificarAcceso(String token) {
    try {
      final jwt = JWT.verify(token, _clave, issuer: emisor);
      // Solo se acepta HS256: evita la confusión de algoritmos.
      if (jwt.header?['alg'] != 'HS256') return null;
      final datos = jwt.payload as Map;
      return UsuarioAutenticado(
        id: int.parse(jwt.subject!),
        nombreUsuario: datos['nombre'] as String,
        rol: Rol.desdeValor(datos['rol'] as String),
      );
    } on JWTException {
      return null;
    } on FormatException {
      return null;
    } on StateError {
      return null;
    } on TypeError {
      return null;
    }
  }

  static String nuevoTokenActualizacion() {
    final aleatorio = Random.secure();
    return base64Url.encode(List.generate(32, (_) => aleatorio.nextInt(256))).replaceAll('=', '');
  }

  static String resumen(String token) => sha256.convert(utf8.encode(token)).toString();
}
