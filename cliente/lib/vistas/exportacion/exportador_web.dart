import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String> guardarArchivo(String nombre, String contenido, String tipo) async {
  final blob = web.Blob(['﻿$contenido'.toJS].toJS, web.BlobPropertyBag(type: tipo));
  final url = web.URL.createObjectURL(blob);
  (web.HTMLAnchorElement()
        ..href = url
        ..download = nombre)
      .click();
  web.URL.revokeObjectURL(url);
  return nombre;
}
