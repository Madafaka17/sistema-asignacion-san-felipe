import 'dart:io';

import 'package:cliente/app.dart';
import 'package:cliente/modelo/api/api_cliente.dart';
import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Recorre, con cada rol, todas las pantallas de su navegación contra el
/// servidor real: comprueba que cada wireframe (docs/wireframes.md) está
/// implementado, que carga sus datos sin errores y que el rol no ve módulos
/// ajenos. Con `--dart-define=CAPTURAS=<carpeta>` guarda una captura de cada
/// pantalla.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const urlApi = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080/api');
  const capturas = String.fromEnvironment('CAPTURAS');

  Future<void> capturar(String nombre) async {
    if (capturas.isEmpty) return;
    await Process.run('import', ['-window', 'root', '$capturas/$nombre.png']);
  }

  Future<void> esperar(WidgetTester tester, Finder buscador) async {
    final fin = DateTime.now().add(const Duration(seconds: 60));
    while (buscador.evaluate().isEmpty) {
      if (DateTime.now().isAfter(fin)) fail('No apareció $buscador');
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
  }

  const usuarios = {
    Rol.despacho: ('jdespacho', 'Despacho2026'),
    Rol.operaciones: ('operaciones', 'Opera2026'),
    Rol.administrador: ('admin', 'Admin2026'),
  };

  testWidgets('cada rol recorre sus pantallas sin errores', (tester) async {
    await tester.pumpWidget(AplicacionSanFelipe(api: ApiCliente(base: Uri.parse(urlApi))));
    await esperar(tester, find.byKey(const Key('campo_usuario')));
    await capturar('00_ingreso');

    for (final MapEntry(key: rol, value: (usuario, contrasena)) in usuarios.entries) {
      await tester.enterText(find.byKey(const Key('campo_usuario')), usuario);
      await tester.enterText(find.byKey(const Key('campo_contrasena')), contrasena);
      await tester.tap(find.byKey(const Key('boton_ingresar')));
      await esperar(tester, find.byKey(const Key('boton_salir')));
      await asentar(tester);

      // Solo los módulos de su rol (HU-01).
      for (final m in Modulo.values) {
        expect(
          find.byKey(Key('modulo_${m.name}')),
          Permisos.modulosNavegacion(rol).contains(m) ? findsOneWidget : findsNothing,
          reason: '${rol.name} / ${m.name}',
        );
      }

      for (final modulo in Permisos.modulosNavegacion(rol)) {
        await tester.tap(find.byKey(Key('modulo_${modulo.name}')));
        await asentar(tester);
        expect(find.byKey(const Key('mensaje_error')), findsNothing, reason: 'la pantalla ${modulo.etiqueta} cargó sin errores');

        switch (modulo) {
          case Modulo.rutas:
            await tester.tap(find.byKey(const ValueKey('ruta_R-03')));
            await esperar(tester, find.byKey(const Key('salida_07:30')));
            await asentar(tester);
          case Modulo.reportes:
            await tester.tap(find.byKey(const Key('boton_generar_reporte')));
            await esperar(tester, find.byWidgetPredicate((w) => w.key == const Key('kpi_psr') || w.key == const Key('reporte_sin_datos')));
            await asentar(tester);
          case Modulo.programacion:
            if (find.byKey(const Key('tabla_asignaciones')).evaluate().isEmpty) {
              await tester.tap(find.byKey(const Key('boton_generar')));
              await esperar(tester, find.byKey(const Key('tabla_asignaciones')));
              await asentar(tester);
            }
          default:
            break;
        }
        await capturar('${rol.name}_${modulo.name}');
      }

      if (rol == Rol.operaciones) {
        // Al volver a la pantalla se ve el detalle de la última ejecución
        // (el listado del servidor trae solo resúmenes).
        await tester.tap(find.byKey(const Key('modulo_programacion')));
        await asentar(tester);
        bool clave(Widget w, String prefijo) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(prefijo);
        expect(find.byWidgetPredicate((w) => clave(w, 'asignacion_')), findsWidgets);

        // HU-09: diálogo de ajuste (solo en una propuesta sin aprobar).
        final ajustar = find.byWidgetPredicate((w) => clave(w, 'ajustar_'));
        if (ajustar.evaluate().isNotEmpty) {
          await tester.tap(ajustar.first);
          await asentar(tester);
          await capturar('operaciones_ajuste');
          await tester.tap(find.text('Cancelar'));
          await asentar(tester);
        }
      }

      await tester.tap(find.byKey(const Key('boton_salir')));
      await esperar(tester, find.byKey(const Key('campo_usuario')));
      await asentar(tester);
    }
  });
}
