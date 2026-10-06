import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:servidor/servidor.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Punto de entrada: lee la configuración del entorno y de
/// `config/parametros.yaml`, abre el pool de MySQL y atiende la API REST.
Future<void> main() async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    stdout.writeln('${r.time.toIso8601String()} ${r.level.name} ${r.loggerName}: ${r.message}');
    if (r.error != null) stdout.writeln('  ${r.error}');
    if (r.stackTrace != null && r.level >= Level.SEVERE) stdout.writeln(r.stackTrace);
  });
  final registro = Logger('servidor');

  final Configuracion configuracion;
  final ParametrosSistema parametros;
  try {
    configuracion = Configuracion.desdeEntorno();
    parametros = ParametrosSistema.desdeArchivo(configuracion.archivoParametros);
  } on Object catch (e) {
    stderr.writeln('Configuración inválida: $e');
    exitCode = 78; // EX_CONFIG
    return;
  }

  final bd = BaseDatos.conectar(
    host: configuracion.dbHost,
    puerto: configuracion.dbPuerto,
    baseDatos: configuracion.dbNombre,
    usuario: configuracion.dbUsuario,
    contrasena: configuracion.dbContrasena,
    tls: configuracion.dbTls,
  );

  final aplicacion = crearAplicacion(bd: bd, configuracion: configuracion, parametros: parametros);
  final servidor = await shelf_io.serve(
    aplicacion,
    InternetAddress.anyIPv4,
    configuracion.puerto,
    poweredByHeader: null, // no revela la tecnología del servidor
  )
    ..autoCompress = true;
  registro.info('Servidor $versionServidor escuchando en el puerto ${servidor.port} '
      '(método de optimización: ${parametros.metodo})');

  final cierre = Completer<void>();
  for (final senal in [ProcessSignal.sigint, if (!Platform.isWindows) ProcessSignal.sigterm]) {
    senal.watch().listen((_) {
      if (!cierre.isCompleted) cierre.complete();
    });
  }
  await cierre.future;
  registro.info('Deteniendo el servidor…');
  await servidor.close();
  await bd.cerrar();
  exit(0);
}
