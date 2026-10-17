import 'dart:io';

import 'package:servidor/servidor.dart';

/// Genera el resumen PBKDF2 de una contraseña para crear o restablecer un
/// usuario directamente en MySQL (por ejemplo, el primer administrador):
///
/// ```sh
/// dart run bin/resumir_contrasena.dart
/// UPDATE usuario SET hash_contrasena = '<resumen>' WHERE nombre_usuario = 'admin';
/// ```
///
/// La contraseña se lee de la entrada estándar sin eco, para que no quede en
/// el historial del intérprete de órdenes.
void main() {
  stdout.write('Contraseña: ');
  final conTerminal = stdin.hasTerminal;
  if (conTerminal) stdin.echoMode = false;
  final contrasena = stdin.readLineSync() ?? '';
  if (conTerminal) {
    stdin.echoMode = true;
    stdout.writeln();
  }
  final debilidad = Contrasenas.validarFortaleza(contrasena);
  if (debilidad != null) {
    stderr.writeln(debilidad);
    exitCode = 1;
    return;
  }
  stdout.writeln(const Contrasenas().resumir(contrasena));
}
