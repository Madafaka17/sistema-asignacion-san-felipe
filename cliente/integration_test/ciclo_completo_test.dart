import 'dart:async';
import 'dart:io';

import 'package:cliente/app.dart';
import 'package:cliente/modelo/api/api_cliente.dart';
import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import 'cliente_grabador.dart';

/// Prueba automatizada de ciclo completo (Sesión 7):
///
///   inserción en la interfaz → procesamiento en el servidor → registro en
///   MySQL → actualización reactiva de la interfaz,
///
/// y, a continuación, el caso de uso principal: generar y aprobar la
/// programación del turno con el servicio recién registrado.
///
/// Requiere el servidor y la base de demostración en marcha (`docker compose
/// up` o `herramientas/e2e.sh`). Configuración con `--dart-define`:
/// `API_URL`, `E2E_DB_HOST`, `E2E_DB_PORT`, `E2E_DB_NAME`, `E2E_DB_USER`,
/// `E2E_DB_PASSWORD` y, opcionalmente, `CAPTURAS` (carpeta para guardar
/// capturas de pantalla con ImageMagick).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const urlApi = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080/api');
  const capturas = String.fromEnvironment('CAPTURAS');

  late ClienteGrabador red;
  late MySQLConnection bd;

  // Código único por ejecución para poder repetir la prueba sobre la misma base.
  final codigo = 'E-${(DateTime.now().millisecondsSinceEpoch ~/ 1000) % 1000000}';
  final hoy = DateTime.now();
  final turno = DateTime.utc(hoy.year, hoy.month, hoy.day + 1);

  setUpAll(() async {
    bd = await MySQLConnection.createConnection(
      host: const String.fromEnvironment('E2E_DB_HOST', defaultValue: '127.0.0.1'),
      port: const int.fromEnvironment('E2E_DB_PORT', defaultValue: 3306),
      userName: const String.fromEnvironment('E2E_DB_USER', defaultValue: 'sanfelipe'),
      password: const String.fromEnvironment('E2E_DB_PASSWORD'),
      databaseName: const String.fromEnvironment('E2E_DB_NAME', defaultValue: 'sanfelipe'),
      secure: true,
    );
    await bd.connect();
  });

  tearDownAll(() => bd.close());

  Future<void> capturar(String nombre) async {
    if (capturas.isEmpty) return;
    await Process.run('import', ['-window', 'root', '$capturas/$nombre.png']);
  }

  /// Espera (con reloj real) a que aparezca [buscador].
  Future<void> esperar(WidgetTester tester, Finder buscador, {Duration limite = const Duration(seconds: 60)}) async {
    final fin = DateTime.now().add(limite);
    while (buscador.evaluate().isEmpty) {
      if (DateTime.now().isAfter(fin)) fail('No apareció $buscador en ${limite.inSeconds} s');
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
  }

  Future<void> ingresar(WidgetTester tester, String usuario, String contrasena) async {
    await esperar(tester, find.byKey(const Key('campo_usuario')));
    await tester.enterText(find.byKey(const Key('campo_usuario')), usuario);
    await tester.enterText(find.byKey(const Key('campo_contrasena')), contrasena);
    await tester.tap(find.byKey(const Key('boton_ingresar')));
    await esperar(tester, find.byKey(const Key('boton_salir')));
    await asentar(tester);
  }

  Future<void> elegir(WidgetTester tester, Finder campo, String opcion) async {
    await tester.tap(campo);
    await asentar(tester);
    await tester.tap(find.text(opcion).last);
    await asentar(tester);
  }

  ButtonStyleButton boton(WidgetTester tester, Key clave) => tester.widget<ButtonStyleButton>(
        find.descendant(of: find.byKey(clave), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
      );

  testWidgets('registro de un servicio: UI → servidor → MySQL → UI, y programación aprobada', (tester) async {
    red = ClienteGrabador(http.Client());
    await tester.pumpWidget(AplicacionSanFelipe(api: ApiCliente(base: Uri.parse(urlApi), cliente: red)));

    // ---- 1. El personal de despacho registra el servicio (HU-06) --------
    await ingresar(tester, 'jdespacho', 'Despacho2026');
    await esperar(tester, find.text('Servicios del turno'));
    await capturar('01_servicios');
    await tester.tap(find.byKey(const Key('boton_nuevo_servicio')));
    await asentar(tester);
    await tester.enterText(find.byKey(const Key('campo_codigo_servicio')), codigo);
    await elegir(tester, find.byKey(const Key('campo_ruta_servicio')), 'R-03 · Soritor – Rioja');
    final rutaR03 = _entero((await bd.execute("SELECT id FROM ruta WHERE codigo = 'R-03'")).rows.single, 'id');
    await elegir(tester, find.byKey(ValueKey('campo_hora_servicio_$rutaR03')), '07:30');
    await elegir(tester, find.byKey(const Key('campo_prioridad_servicio')), 'Alta (3)');
    await tester.enterText(find.byKey(const Key('campo_capacidad_servicio')), '4');
    await capturar('02_formulario_servicio');

    final listasAntes = red.de('GET', '/api/servicios').length;
    final liberar = Completer<void>();
    red.retener = (metodo: 'POST', ruta: '/api/servicios', liberar: liberar);
    await tester.tap(find.byKey(const Key('boton_guardar_servicio')));
    await esperar(tester, find.byWidgetPredicate((w) => w is CircularProgressIndicator));

    // a) La interfaz desactiva la acción mientras la solicitud está en curso.
    expect(boton(tester, const Key('boton_guardar_servicio')).onPressed, isNull);
    await tester.tap(find.byKey(const Key('boton_guardar_servicio')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(red.de('POST', '/api/servicios'), hasLength(1), reason: 'un segundo toque no genera otra solicitud');
    await capturar('03_guardando');

    // b) El payload tiene la estructura y los tipos del contrato.
    final envio = red.de('POST', '/api/servicios').single;
    expect(envio.cuerpoEnviado, {
      'codigo': codigo,
      'fecha': fechaATexto(turno),
      'rutaId': rutaR03,
      'horaSolicitada': 450,
      'prioridad': 3,
      'capacidadRequerida': 4,
    });

    liberar.complete();
    await esperar(tester, find.byKey(ValueKey('servicio_$codigo')));
    await asentar(tester);

    // c) El cliente interceptó HTTP 201 con el servicio creado.
    expect(envio.estado, 201);
    final creado = ServicioProgramado.fromJson(envio.cuerpoRecibido);
    expect(creado.estado, EstadoServicio.pendiente);

    // d) MySQL guardó el registro con los mismos valores.
    final fila = (await bd.execute(
      'SELECT s.id, s.fecha, s.hora_solicitada, s.prioridad, s.capacidad_requerida, s.estado, u.nombre_usuario '
      'FROM servicio s JOIN usuario u ON u.id = s.creado_por WHERE s.codigo = :c',
      {'c': codigo},
    ))
        .rows
        .single;
    expect(_entero(fila, 'id'), creado.id);
    expect(fila.colByName('fecha'), startsWith(fechaATexto(turno)));
    expect(_entero(fila, 'hora_solicitada'), 450);
    expect(_entero(fila, 'prioridad'), 3);
    expect(_entero(fila, 'capacidad_requerida'), 4);
    expect(fila.colByName('estado'), 'pendiente');
    expect(fila.colByName('nombre_usuario'), 'jdespacho');

    // e) La tabla se actualizó con la respuesta, sin recargar la lista ni la página.
    expect(find.byType(AlertDialog), findsNothing);
    expect(red.de('GET', '/api/servicios').length, listasAntes);
    await capturar('04_servicio_registrado');

    // ---- 2. Operaciones genera y aprueba la programación (HU-07 a HU-09) -
    await tester.tap(find.byKey(const Key('boton_salir')));
    await asentar(tester);
    await ingresar(tester, 'operaciones', 'Opera2026');
    await esperar(tester, find.byKey(const Key('boton_generar')));
    await tester.tap(find.byKey(const Key('boton_generar')));
    await esperar(tester, find.byKey(const Key('kpi_phi')), limite: const Duration(seconds: 320));
    await esperar(tester, find.byKey(ValueKey('asignacion_$codigo')));
    await asentar(tester);
    await capturar('05_propuesta');

    final generacion = red.de('POST', '/api/programaciones').last;
    expect(generacion.estado, 201);
    final propuesta = Programacion.fromJson(generacion.cuerpoRecibido! as Map<String, Object?>);
    expect(propuesta.phiValidador, 0, reason: 'RNF-01: el validador independiente confirma Φ = 0');
    final asignacion = propuesta.asignaciones.singleWhere((a) => a.codigoServicio == codigo);
    expect(asignacion.estado, EstadoAsignacion.asignado);
    expect(asignacion.salida, 450);

    await tester.tap(find.text('Gantt'));
    await asentar(tester);
    await capturar('06_gantt');
    await tester.tap(find.text('Convergencia'));
    await asentar(tester);
    await capturar('07_convergencia');
    await tester.tap(find.text('Asignaciones'));
    await asentar(tester);

    await tester.tap(find.byKey(const Key('boton_aprobar')));
    await esperar(tester, find.text('Programación aprobada'));
    await asentar(tester);
    await capturar('08_aprobada');

    final aprobada = (await bd.execute(
      'SELECT p.estado, s.estado AS estado_servicio FROM programacion p '
      'JOIN asignacion a ON a.programacion_id = p.id JOIN servicio s ON s.id = a.servicio_id '
      'WHERE p.id = :p AND s.codigo = :c',
      {'p': propuesta.id, 'c': codigo},
    ))
        .rows
        .single;
    expect(aprobada.colByName('estado'), 'aprobada');
    expect(aprobada.colByName('estado_servicio'), 'programado');
    final bitacora = await bd.execute(
      "SELECT COUNT(*) AS n FROM bitacora WHERE accion = 'aprobar_programacion' AND entidad_id = :p",
      {'p': propuesta.id},
    );
    expect(_entero(bitacora.rows.single, 'n'), 1);
  });
}

int _entero(ResultSetRow fila, String columna) => int.parse('${fila.colByName(columna)}');
