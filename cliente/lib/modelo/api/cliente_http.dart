/// Crea el `http.Client` de la plataforma: en la web, uno que envía las
/// cookies (`withCredentials`); en escritorio, el de `dart:io`.
library;

export 'cliente_http_io.dart' if (dart.library.js_interop) 'cliente_http_web.dart';
