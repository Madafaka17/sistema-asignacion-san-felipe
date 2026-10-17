/// Guarda un archivo generado en el cliente: en la web lo descarga el
/// navegador; en escritorio se escribe en la carpeta de descargas.
library;

export 'exportador_io.dart' if (dart.library.js_interop) 'exportador_web.dart';
