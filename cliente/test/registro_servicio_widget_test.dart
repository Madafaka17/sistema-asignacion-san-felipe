import 'dart:async';
import 'dart:convert';

import 'package:cliente/app.dart';
import 'package:cliente/modelo/api/api_cliente.dart';
import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoyo/servidor_simulado.dart';

/// HU-06 en la interfaz con un servidor simulado: el formulario envía el
/// payload del contrato, el botón no permite un segundo envío mientras la
/// solicitud está en curso y la tabla se actualiza con la respuesta 201 sin
/// volver a pedir la lista.
void main() {
  late ServidorSimulado servidor;
  late Completer<void> liberarRespuesta;

  const ruta = Ruta(id: 3, codigo: 'R-03', origen: 'Soritor', destino: 'Rioja', duracionMin: 95);

  setUp(() {
    servidor = ServidorSimulado()..conSesion(usuarioDespacho);
    servidor
      ..en('GET', '/api/servicios', (_) => ServidorSimulado.json(
            const Pagina<ServicioProgramado>(elementos: [], total: 0, pagina: 1, tamano: 200).toJson((s) => s.toJson()),
          ))
      ..en('GET', '/api/rutas', (_) => ServidorSimulado.json([ruta.toJson()]))
      ..en('GET', '/api/rutas/3/salidas', (_) => ServidorSimulado.json([
            const SalidaAutorizada(id: 9, rutaId: 3, hora: 450).toJson(),
          ]))
      ..en('POST', '/api/servicios', (s) async {
        await liberarRespuesta.future; // la solicitud queda «en curso»
        final datos = ServicioProgramado.fromJson(jsonDecode(s.body));
        return ServidorSimulado.json(
          ServicioProgramado(
            id: 115,
            codigo: datos.codigo,
            fecha: datos.fecha,
            rutaId: datos.rutaId,
            horaSolicitada: datos.horaSolicitada,
            prioridad: datos.prioridad,
            capacidadRequerida: datos.capacidadRequerida,
            codigoRuta: 'R-03',
          ).toJson(),
          201,
        );
      });
  });

  Future<void> ingresar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AplicacionSanFelipe(api: ApiCliente(base: Uri.parse('http://servidor/api'), cliente: servidor.cliente)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_usuario')), 'jdespacho');
    await tester.enterText(find.byKey(const Key('campo_contrasena')), 'Despacho2026');
    await tester.tap(find.byKey(const Key('boton_ingresar')));
    await tester.pumpAndSettle();
  }

  ButtonStyleButton botonDe(WidgetTester tester, Key clave) => tester.widget<ButtonStyleButton>(
        find.descendant(of: find.byKey(clave), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
      );

  testWidgets('HU-01: el despacho solo ve sus módulos', (tester) async {
    await ingresar(tester);
    for (final m in Permisos.modulosNavegacion(Rol.despacho)) {
      expect(find.byKey(Key('modulo_${m.name}')), findsOneWidget, reason: m.etiqueta);
    }
    expect(find.byKey(const Key('modulo_programacion')), findsNothing);
    expect(find.byKey(const Key('modulo_reportes')), findsNothing);
    expect(find.byKey(const Key('modulo_usuarios')), findsNothing);
  });

  testWidgets('HU-06: registrar S-115 envía el payload correcto una sola vez y actualiza la tabla sin recargar', (tester) async {
    await ingresar(tester);
    expect(find.text('Servicios del turno'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_nuevo_servicio')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_codigo_servicio')), 's-115');
    await tester.tap(find.byKey(const Key('campo_ruta_servicio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('R-03 · Soritor – Rioja').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('campo_hora_servicio_3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('07:30').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campo_prioridad_servicio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alta (3)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_capacidad_servicio')), '10');

    // Se crea dentro de la prueba (zona de tiempo simulado de testWidgets).
    liberarRespuesta = Completer<void>();
    final listasAntes = servidor.de('GET', '/api/servicios').length;
    await tester.tap(find.byKey(const Key('boton_guardar_servicio')));
    await tester.pump();

    // Mientras el servidor no responde, el botón está desactivado: un
    // segundo toque no envía otra solicitud.
    expect(botonDe(tester, const Key('boton_guardar_servicio')).onPressed, isNull);
    await tester.tap(find.byKey(const Key('boton_guardar_servicio')), warnIfMissed: false);
    await tester.pump();
    expect(servidor.de('POST', '/api/servicios'), hasLength(1));

    // Payload con la estructura y los tipos del contrato.
    final envio = servidor.de('POST', '/api/servicios').single;
    expect(envio.cabeceras['authorization'], 'Bearer token-de-prueba');
    expect(envio.cabeceras['x-version-cliente'], '1.0.0');
    expect(envio.cuerpo, {
      'codigo': 'S-115',
      'fecha': isA<String>().having((f) => intentarTextoAFecha(f), 'fecha válida', isNotNull),
      'rutaId': 3,
      'horaSolicitada': 450,
      'prioridad': 3,
      'capacidadRequerida': 10,
    });

    // El servidor responde 201: el diálogo se cierra y la fila aparece.
    liberarRespuesta.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const ValueKey('servicio_S-115')), findsOneWidget);
    expect(find.text('Servicio registrado'), findsOneWidget);
    expect(servidor.de('GET', '/api/servicios').length, listasAntes, reason: 'actualización reactiva, sin recargar la lista');
  });

  testWidgets('HU-06 (error): sin ruta no se envía y se resalta el campo «Ruta»', (tester) async {
    await ingresar(tester);
    await tester.tap(find.byKey(const Key('boton_nuevo_servicio')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_codigo_servicio')), 'S-116');
    await tester.tap(find.byKey(const Key('boton_guardar_servicio')));
    await tester.pumpAndSettle();
    expect(find.text('Seleccione una ruta'), findsOneWidget);
    expect(servidor.de('POST', '/api/servicios'), isEmpty);
  });

  testWidgets('un rechazo del servidor (409) se muestra en el campo y el diálogo sigue abierto', (tester) async {
    servidor.en('POST', '/api/servicios', (_) => ServidorSimulado.json(
          ExcepcionApi(CodigoError.conflicto, 'El código de servicio ya está registrado',
              campos: {'codigo': 'El código de servicio ya está registrado'}).toJson(),
          409,
        ));
    await ingresar(tester);
    await tester.tap(find.byKey(const Key('boton_nuevo_servicio')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_codigo_servicio')), 'S-115');
    await tester.tap(find.byKey(const Key('campo_ruta_servicio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('R-03 · Soritor – Rioja').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('campo_hora_servicio_3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('07:30').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_servicio')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('El código de servicio ya está registrado'), findsWidgets);
    expect(find.byKey(const ValueKey('servicio_S-115')), findsNothing);
  });
}
