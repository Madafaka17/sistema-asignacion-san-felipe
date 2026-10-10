import 'dart:io';

/// Devuelve la ruta donde quedó el archivo.
Future<String> guardarArchivo(String nombre, String contenido, String tipo) async {
  final inicio = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  final descargas = inicio == null ? null : Directory('$inicio${Platform.pathSeparator}Downloads');
  final carpeta = descargas != null && descargas.existsSync() ? descargas : Directory.systemTemp;
  final archivo = File('${carpeta.path}${Platform.pathSeparator}$nombre');
  // BOM para que Excel reconozca las tildes del CSV en UTF-8.
  await archivo.writeAsString('﻿$contenido');
  return archivo.path;
}
