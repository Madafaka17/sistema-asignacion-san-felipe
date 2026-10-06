import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Resumen criptográfico de contraseñas con PBKDF2-HMAC-SHA256 (RNF-06).
///
/// Formato guardado: `pbkdf2_sha256$<iteraciones>$<sal base64>$<hash base64>`.
/// Las iteraciones quedan en el propio resumen, así que pueden aumentarse sin
/// invalidar las contraseñas existentes.
class Contrasenas {
  const Contrasenas({this.iteraciones = 100000});

  final int iteraciones;

  static const _prefijo = 'pbkdf2_sha256';
  static const _longitud = 32;

  String resumir(String contrasena, {List<int>? sal}) {
    final salUsada = sal ?? _salAleatoria();
    final hash = pbkdf2Sha256(utf8.encode(contrasena), salUsada, iteraciones, _longitud);
    return '$_prefijo\$$iteraciones\$${base64.encode(salUsada)}\$${base64.encode(hash)}';
  }

  /// Compara en tiempo constante para no revelar información por el tiempo
  /// de respuesta.
  bool verificar(String contrasena, String resumen) {
    final partes = resumen.split(r'$');
    if (partes.length != 4 || partes[0] != _prefijo) return false;
    final iteracionesGuardadas = int.tryParse(partes[1]);
    if (iteracionesGuardadas == null || iteracionesGuardadas < 1) return false;
    final sal = base64.decode(partes[2]);
    final esperado = base64.decode(partes[3]);
    final calculado = pbkdf2Sha256(utf8.encode(contrasena), sal, iteracionesGuardadas, esperado.length);
    var diferencia = 0;
    for (var i = 0; i < esperado.length; i++) {
      diferencia |= esperado[i] ^ calculado[i];
    }
    return diferencia == 0;
  }

  static List<int> _salAleatoria() {
    final aleatorio = Random.secure();
    return List.generate(16, (_) => aleatorio.nextInt(256));
  }

  /// Política mínima de contraseñas.
  static String? validarFortaleza(String contrasena) {
    if (contrasena.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(contrasena) || !RegExp(r'[0-9]').hasMatch(contrasena)) {
      return 'La contraseña debe combinar letras y números';
    }
    return null;
  }
}

/// PBKDF2 (RFC 8018) con HMAC-SHA256.
Uint8List pbkdf2Sha256(List<int> contrasena, List<int> sal, int iteraciones, int longitud) {
  final hmac = Hmac(sha256, contrasena);
  final salida = BytesBuilder();
  for (var bloque = 1; salida.length < longitud; bloque++) {
    var u = hmac.convert([
      ...sal,
      (bloque >> 24) & 0xff,
      (bloque >> 16) & 0xff,
      (bloque >> 8) & 0xff,
      bloque & 0xff,
    ]).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iteraciones; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    salida.add(t);
  }
  return Uint8List.sublistView(salida.toBytes(), 0, longitud);
}
