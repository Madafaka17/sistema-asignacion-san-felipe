import 'dart:io';

import 'package:cliente/app.dart';
import 'package:cliente/modelo/api/api_cliente.dart';
import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Caso real (tesis, sección 5.6.2; rúbrica del EP3, criterio 15(b) y 15(d)).
///
/// Recorre la interfaz con la salida registrada en el manifiesto de pasajeros
/// 001-029483 de la empresa (RD-02, Anexo B, Tabla B1), cuyo uso para
/// investigación autorizó la empresa por escrito el 5/10/2026 (Figura B3):
///
///   fecha 03/10/2026 · origen Soritor · destino Tarapoto · hora consignada
///   4:00 a. m. · 16 asientos · 15 pasajeros en origen · unidad V001 ·
///   conductor C041.
///
/// Se ejecuta sobre una base vacía (esquema y cuentas del sistema, sin los
/// datos de demostración) y solo con `--dart-define=CASO_REAL=true`; los
/// datos que el manifiesto no consigna se declaran en
/// docs/evidencias/caso_real_001-029483/README.md. Guarda una captura por paso
/// en `--dart-define=CAPTURAS=<carpeta>` (ImageMagick `import`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const urlApi = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8090/api');
  const capturas = String.fromEnvironment('CAPTURAS');
  const habilitado = bool.fromEnvironment('CASO_REAL');

  // ---- Datos del manifiesto 001-029483 (Tabla B1) -------------------------
  const manifiesto = '001-029483';
  final fecha = DateTime.utc(2026, 10, 3);
  const unidad = 'V001';
  const conductor = 'C041';
  const asientos = '16';
  const pasajeros = '15';
  const salida = '04:00';
  // ---- Datos declarados por la empresa (sección 1.2) -----------------------
  const ruta = 'R-02';
  const destino = 'Tarapoto';
  const idaDeclarada = '150';
  // ---- Supuestos y seudónimos (README de la evidencia) ---------------------
  const placaSeudonimo = 'SFP-001'; // placa oculta en el manifiesto
  const dniSeudonimo = '00000041'; // el manifiesto no se usa para datos personales
  const cicloSupuesto = '330'; // 2 × 150 min + 30 min de estancia (supuesto de la tesis)
  const vencimientoSupuesto = '2027-10-03'; // vigente: condujo esa salida
  const llegadaSupuesta = '03:30'; // llegada a la cola no consignada; anterior a la salida

  late WidgetTester probador;

  /// Captura la pantalla después de que el último cambio se haya dibujado.
  Future<void> capturar(String nombre) async {
    if (capturas.isEmpty) return;
    for (var i = 0; i < 5; i++) {
      await probador.pump(const Duration(milliseconds: 100));
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await probador.pump();
    await Process.run('import', ['-window', 'root', '$capturas/$nombre.png']);
  }

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

  Future<void> salir(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boton_salir')));
    await esperar(tester, find.byKey(const Key('campo_usuario')));
    await asentar(tester);
  }

  Future<void> modulo(WidgetTester tester, Modulo m) async {
    await tester.tap(find.byKey(Key('modulo_${m.name}')));
    await asentar(tester);
  }

  Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

  Future<void> escribir(WidgetTester tester, Finder f, String texto) async {
    await tester.ensureVisible(f);
    await tester.enterText(f, texto);
    await asentar(tester);
  }

  Future<void> elegir(WidgetTester tester, Finder f, String opcion) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await asentar(tester);
    await tester.tap(find.text(opcion).last);
    await asentar(tester);
  }

  Future<void> guardar(WidgetTester tester, Key clave) async {
    await tester.ensureVisible(find.byKey(clave));
    await tester.tap(find.byKey(clave));
    final fin = DateTime.now().add(const Duration(seconds: 30));
    while (find.byKey(clave).evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(fin)) fail('El formulario no se cerró al guardar ($clave)');
      await tester.pump(const Duration(milliseconds: 100));
    }
    await asentar(tester);
  }

  /// Elige la fecha del turno con el calendario, en modo de entrada de texto.
  Future<void> elegirFecha(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.calendar_month).first);
    await asentar(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await asentar(tester);
    final dd = fecha.day.toString().padLeft(2, '0');
    final mm = fecha.month.toString().padLeft(2, '0');
    await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '$dd/$mm/${fecha.year}');
    await asentar(tester);
    // Botón de confirmación del calendario (el último del diálogo: «Cancelar», «Aceptar»).
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)).last);
    await asentar(tester);
    expect(find.textContaining('03/10/2026'), findsWidgets, reason: 'la pantalla muestra el turno del 03/10/2026');
  }

  testWidgets('caso real: manifiesto $manifiesto (Soritor–Tarapoto, 03/10/2026)', (tester) async {
    probador = tester;
    await tester.pumpWidget(AplicacionSanFelipe(api: ApiCliente(base: Uri.parse(urlApi))));
    await esperar(tester, find.byKey(const Key('campo_usuario')));
    await capturar('00_ingreso');

    // ---- 1. Despacho registra la unidad del manifiesto (HU-02, CU-02) -----
    await ingresar(tester, 'jdespacho', 'Despacho2026');
    await modulo(tester, Modulo.vehiculos);
    await tester.tap(find.byKey(const Key('boton_nuevo_vehiculo')));
    await asentar(tester);
    await escribir(tester, find.byKey(const Key('campo_codigo_vehiculo')), unidad);
    await escribir(tester, find.byKey(const Key('campo_placa')), placaSeudonimo);
    await escribir(tester, find.byKey(const Key('campo_capacidad')), asientos);
    await capturar('01_formulario_unidad');
    await guardar(tester, const Key('boton_guardar_vehiculo'));
    await esperar(tester, find.byKey(const ValueKey('vehiculo_$unidad')));
    await capturar('02_unidad_registrada');

    // ---- 2. Despacho registra el conductor del manifiesto (HU-03, CU-03) --
    await modulo(tester, Modulo.conductores);
    await tester.tap(find.byKey(const Key('boton_nuevo_conductor')));
    await asentar(tester);
    await escribir(tester, campo('Código'), conductor);
    await escribir(tester, campo('DNI'), dniSeudonimo);
    await escribir(tester, campo('Nombres'), 'Conductor');
    await escribir(tester, campo('Apellidos'), '$conductor (seudónimo)');
    await escribir(tester, campo('Vencimiento de la licencia'), vencimientoSupuesto);
    await escribir(tester, campo('Inicio de turno'), '00:00');
    await escribir(tester, campo('Fin de turno'), '23:59');
    await capturar('03_formulario_conductor');
    await guardar(tester, const Key('boton_guardar_conductor'));
    await esperar(tester, find.byKey(const ValueKey('conductor_$conductor')));
    await capturar('04_conductor_registrado');

    // ---- 3. Par autorizado: C041 es el conductor habitual de V001 ----------
    await modulo(tester, Modulo.vehiculos);
    await tester.ensureVisible(find.byKey(const ValueKey('conductores_$unidad')));
    await asentar(tester);
    await tester.tap(find.byKey(const ValueKey('conductores_$unidad')));
    await asentar(tester);
    await elegir(tester, find.byKey(const Key('campo_conductor_habitual')), '$conductor · Conductor $conductor (seudónimo)');
    await capturar('05_par_autorizado');
    await guardar(tester, const Key('boton_guardar_conductores'));

    // ---- 4. Ruta Soritor–Tarapoto y salida autorizada de las 04:00 (HU-04/05)
    await modulo(tester, Modulo.rutas);
    await tester.tap(find.byKey(const Key('boton_nueva_ruta')));
    await asentar(tester);
    await escribir(tester, campo('Código'), ruta);
    await escribir(tester, campo('Destino'), destino);
    await escribir(tester, find.byKey(const Key('campo_duracion_ruta')), cicloSupuesto);
    await escribir(tester, find.byKey(const Key('campo_ida_ruta')), idaDeclarada);
    await tester.ensureVisible(find.text('$unidad ($asientos)'));
    await tester.tap(find.text('$unidad ($asientos)'));
    await asentar(tester);
    await capturar('06_formulario_ruta');
    await guardar(tester, const Key('boton_guardar_ruta'));
    await tester.tap(find.byKey(const ValueKey('ruta_$ruta')));
    await asentar(tester);
    await escribir(tester, find.byKey(const Key('campo_hora_salida')), salida);
    await tester.tap(find.byKey(const Key('boton_agregar_salida')));
    await esperar(tester, find.byKey(const Key('salida_$salida')));
    await asentar(tester);
    await capturar('07_ruta_y_salida');

    // ---- 5. Llegada de V001 a la cola de Tarapoto del 03/10/2026 (CU-05) --
    await modulo(tester, Modulo.cola);
    await elegirFecha(tester);
    await tester.tap(find.byKey(const Key('boton_registrar_llegada')));
    await asentar(tester);
    await elegir(tester, find.byKey(const Key('campo_unidad_llegada')), '$unidad · $placaSeudonimo');
    await escribir(tester, find.byKey(const Key('campo_hora_llegada')), llegadaSupuesta);
    await capturar('08_formulario_llegada');
    await guardar(tester, const Key('boton_guardar_llegada'));
    await esperar(tester, find.byKey(const ValueKey('entrada_1')));
    await capturar('09_cola_tarapoto');

    // ---- 6. Servicio del manifiesto (HU-06, CU-06) -------------------------
    await modulo(tester, Modulo.servicios);
    await elegirFecha(tester);
    await tester.tap(find.byKey(const Key('boton_nuevo_servicio')));
    await asentar(tester);
    await escribir(tester, find.byKey(const Key('campo_codigo_servicio')), manifiesto);
    await elegir(tester, find.byKey(const Key('campo_ruta_servicio')), '$ruta · Soritor – $destino');
    await elegir(tester, find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('campo_hora_servicio_')), salida);
    await escribir(tester, find.byKey(const Key('campo_capacidad_servicio')), pasajeros);
    await capturar('10_formulario_servicio');
    await guardar(tester, const Key('boton_guardar_servicio'));
    await esperar(tester, find.byKey(const ValueKey('servicio_$manifiesto')));
    await capturar('11_servicio_registrado');
    await salir(tester);

    // ---- 7. Operaciones genera, revisa y aprueba (HU-07 a HU-09) -----------
    await ingresar(tester, 'operaciones', 'Opera2026');
    await modulo(tester, Modulo.programacion);
    await elegirFecha(tester);
    await tester.tap(find.byKey(const Key('boton_generar')));
    await esperar(tester, find.byKey(const Key('kpi_phi')), limite: const Duration(seconds: 320));
    await esperar(tester, find.byKey(const ValueKey('asignacion_$manifiesto')));
    await asentar(tester);
    await capturar('12_propuesta');
    // La propuesta coincide con el despacho registrado en el manifiesto: V001 con C041 a las 04:00.
    final tabla = find.byKey(const Key('tabla_asignaciones'));
    for (final esperado in [manifiesto, unidad, conductor, salida]) {
      expect(find.descendant(of: tabla, matching: find.text(esperado)), findsWidgets, reason: 'la propuesta muestra $esperado');
    }
    await tester.tap(find.text('Gantt'));
    await asentar(tester);
    await capturar('13_gantt');
    await tester.tap(find.text('Asignaciones'));
    await asentar(tester);
    await tester.tap(find.byKey(const Key('boton_aprobar')));
    await esperar(tester, find.text('Programación aprobada'));
    await asentar(tester);
    await capturar('14_aprobada');
    await salir(tester);
  }, skip: !habilitado);
}
