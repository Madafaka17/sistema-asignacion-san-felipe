import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

import '../apoyo/entorno.dart';
import '../apoyo/escenario.dart';

/// Reglas de cola y de conductores de la sección 3.1.2 de la tesis: las
/// unidades salen por orden de llegada (`π`, `v0(s)`, `v1(s)`), cada unidad
/// tiene su conductor habitual y sus reemplazos autorizados (`chab(v)`,
/// `C_v^R`) y la programación registra `σ(s)`, `η(s)` y `Δt(s)`.
void main() {
  late Entorno entorno;

  setUpAll(() async => entorno = await Entorno.iniciar());
  setUp(() => entorno.reiniciar());
  tearDownAll(() => entorno.cerrar());

  Future<Respuesta> llegar(int rutaId, int vehiculoId, String hora, {String como = 'jdespacho'}) => entorno.post(
        '/api/cola',
        {'rutaId': rutaId, 'fecha': Entorno.turno, 'vehiculoId': vehiculoId, 'llegada': horaAMinutos(hora)},
        como: como,
      );

  Future<List<EntradaCola>> colaDe(int rutaId) async => [
        for (final e in (await entorno.get('/api/cola?fecha=${Entorno.turno}&rutaId=$rutaId', como: 'jdespacho')).lista)
          EntradaCola.fromJson(e),
      ];

  /// R-01 de 90 min con salidas a las 06:00, 06:30 y 07:00; V-01, V-02 y
  /// V-03 forman cola en ese orden; C-01, C-02 y C-03 son sus habituales y
  /// C-09 es reemplazo autorizado de las tres.
  Future<({List<int> v, Map<String, int> c, int ruta, List<int> cola})> base() async {
    final v = [
      await entorno.vehiculo('V-01', 'AHK-101', capacidad: 16),
      await entorno.vehiculo('V-02', 'AHK-102', capacidad: 16),
      await entorno.vehiculo('V-03', 'AHK-103', capacidad: 16),
    ];
    final c = {
      for (final (codigo, dni) in [('C-01', '70000001'), ('C-02', '70000002'), ('C-03', '70000003'), ('C-09', '70000009')])
        codigo: await entorno.conductor(codigo, dni, inicio: '05:00', fin: '19:00'),
    };
    for (final (i, habitual) in ['C-01', 'C-02', 'C-03'].indexed) {
      expect((await entorno.autorizar(v[i], habitual: c[habitual], reemplazos: [c['C-09']!])).estado, 200);
    }
    final ruta = await entorno.ruta('R-01', 90, v, salidas: ['06:00', '06:30', '07:00']);
    final cola = [
      await entorno.llegada(ruta, v[0], '05:20'),
      await entorno.llegada(ruta, v[1], '05:25'),
      await entorno.llegada(ruta, v[2], '05:30'),
    ];
    return (v: v, c: c, ruta: ruta, cola: cola);
  }

  group('Cola de despacho', () {
    test('las llegadas reciben la posición siguiente y la cola se lista por orden de llegada', () async {
      final b = await base();
      final cola = await colaDe(b.ruta);
      expect([for (final e in cola) (e.posicion, e.codigoVehiculo, minutosAHora(e.llegada))], [
        (1, 'V-01', '05:20'),
        (2, 'V-02', '05:25'),
        (3, 'V-03', '05:30'),
      ]);
      expect(cola.every((e) => e.libre), isTrue);
      final eventos = await entorno.consultar("SELECT COUNT(*) AS n FROM bitacora WHERE accion = 'registrar_llegada'");
      expect(eventos.single.entero('n'), 3);
    });

    test('una unidad no operativa, incompatible, que ya espera turno o que llega antes de la última no entra', () async {
      final b = await base();
      final v04 = await entorno.vehiculo('V-04', 'AHK-104', estado: 'mantenimiento');
      final v05 = await entorno.vehiculo('V-05', 'AHK-105');
      final ruta = await entorno.ruta('R-09', 90, [b.v[0], v04], salidas: ['06:00']);

      final mantenimiento = await llegar(ruta, v04, '06:00');
      expect(mantenimiento.estado, 422);
      expect(mantenimiento.camposError['vehiculoId'], 'La unidad V-04 no está operativa');

      final incompatible = await llegar(b.ruta, v05, '06:00');
      expect(incompatible.estado, 422);
      expect(incompatible.camposError['vehiculoId'], 'La unidad V-05 no es compatible con la ruta R-01');

      final enEspera = await llegar(ruta, b.v[0], '06:00');
      expect(enEspera.estado, 409);
      expect(enEspera.mensajeError, 'La unidad V-01 ya espera turno en la posición 1 de la cola de R-01');

      await entorno.servicio('S-001', b.ruta, '06:00', entrada: b.cola[0]);
      final antes = await llegar(b.ruta, b.v[0], '05:00');
      expect(antes.estado, 422);
      expect(antes.camposError['llegada'], 'La cola es por orden de llegada: la última unidad llegó a las 05:30');
      expect((await llegar(b.ruta, b.v[0], '07:30')).estado, 201, reason: 'V-01 vuelve a la cola tras su viaje');
    });

    test('retirar una unidad la deja inactiva con su posición; solo el despacho registra', () async {
      final b = await base();
      final r = await entorno.post('/api/cola/${b.cola[1]}/retirar', null, como: 'jdespacho');
      expect(r.estado, 200, reason: '$r');
      expect(EntradaCola.fromJson(r.mapa).activa, isFalse);
      expect((await colaDe(b.ruta)).map((e) => (e.posicion, e.activa)), [(1, true), (2, false), (3, true)]);
      expect((await entorno.post('/api/cola/${b.cola[1]}/retirar', null, como: 'jdespacho')).estado, 422);

      expect((await llegar(b.ruta, b.v[1], '08:00', como: 'operaciones')).estado, 403);
      expect((await entorno.get('/api/cola?fecha=${Entorno.turno}', como: 'operaciones')).estado, 200);
      expect((await entorno.get('/api/cola', como: 'jdespacho')).estado, 400);
    });
  });

  group('Servicio con turno en la cola (HU-06)', () {
    test('el servicio toma el turno, lo muestra y lo libera al cancelarse', () async {
      final b = await base();
      final id = await entorno.servicio('S-001', b.ruta, '06:00', entrada: b.cola[0]);
      final s = ServicioProgramado.fromJson((await entorno.get('/api/servicios/$id', como: 'jdespacho')).mapa);
      expect((s.entradaColaId, s.codigoVehiculoCola, s.posicionCola), (b.cola[0], 'V-01', 1));
      expect((await colaDe(b.ruta)).first.codigoServicio, 'S-001');

      final otro = await entorno.post(
        '/api/servicios',
        {
          'codigo': 'S-002',
          'fecha': Entorno.turno,
          'rutaId': b.ruta,
          'horaSolicitada': 360,
          'prioridad': 2,
          'capacidadRequerida': 4,
          'entradaColaId': b.cola[0],
        },
        como: 'jdespacho',
      );
      expect(otro.estado, 409);
      expect(otro.camposError['entradaColaId'], 'El turno de V-01 (posición 1) ya corresponde al servicio S-001');

      expect((await entorno.post('/api/servicios/$id/cancelar', null, como: 'jdespacho')).estado, 200);
      expect((await colaDe(b.ruta)).first.libre, isTrue);
      await entorno.servicio('S-002', b.ruta, '06:00', entrada: b.cola[0]);
    });

    test('el turno debe ser de la misma ruta, seguir en la cola y llegar antes de la salida', () async {
      final b = await base();
      final otraRuta = await entorno.ruta('R-02', 330, b.v, salidas: ['05:00']);
      Future<Respuesta> crear(int ruta, String hora, int entrada) => entorno.post(
            '/api/servicios',
            {
              'codigo': 'S-009',
              'fecha': Entorno.turno,
              'rutaId': ruta,
              'horaSolicitada': horaAMinutos(hora),
              'prioridad': 2,
              'capacidadRequerida': 4,
              'entradaColaId': entrada,
            },
            como: 'jdespacho',
          );
      expect((await crear(otraRuta, '05:00', b.cola[0])).camposError['entradaColaId'],
          'El turno elegido es de la cola de otra ruta o de otra fecha');
      await entorno.salida(b.ruta, '05:00');
      expect((await crear(b.ruta, '05:00', b.cola[0])).camposError['entradaColaId'],
          'La unidad V-01 llega a la cola a las 05:20, después de la salida solicitada');
      await entorno.post('/api/cola/${b.cola[2]}/retirar', null, como: 'jdespacho');
      expect((await crear(b.ruta, '06:00', b.cola[2])).camposError['entradaColaId'], 'La unidad V-03 dejó la cola');
    });
  });

  group('Conductores autorizados de cada unidad', () {
    test('se registran el habitual y los reemplazos, con su bitácora', () async {
      final b = await base();
      final r = await entorno.get('/api/vehiculos/${b.v[0]}/conductores', como: 'operaciones');
      final autorizados = ConductoresAutorizados.fromJson(r.mapa);
      expect(autorizados.conductorHabitualId, b.c['C-01']);
      expect(autorizados.reemplazos, [b.c['C-09']]);

      final pares = [for (final p in (await entorno.get('/api/pares', como: 'jdespacho')).lista) ParAutorizado.fromJson(p)];
      expect(pares.where((p) => p.tipo == TipoPar.habitual), hasLength(3));
      expect(pares.where((p) => p.conductorId == b.c['C-09']), hasLength(3));

      final evento = (await entorno.consultar(
        "SELECT detalle FROM bitacora WHERE accion = 'asignar_conductores' AND entidad_id = :v",
        {'v': b.v[0]},
      ))
          .single;
      final detalle = evento.json('detalle') as Map<String, Object?>;
      expect((detalle['despues'] as Map<String, Object?>)['conductorHabitualId'], b.c['C-01']);
    });

    test('un conductor es habitual de una sola unidad y no puede ser a la vez su reemplazo', () async {
      final b = await base();
      final duplicado = await entorno.autorizar(b.v[1], habitual: b.c['C-01']);
      expect(duplicado.estado, 409);
      expect(duplicado.camposError['conductorHabitualId'], 'C-01 ya es conductor habitual de V-01');

      final repetido = await entorno.autorizar(b.v[0], habitual: b.c['C-01'], reemplazos: [b.c['C-01']!]);
      expect(repetido.estado, 422);
      expect(repetido.camposError['reemplazos'], 'El conductor habitual no puede figurar también como reemplazo');

      expect((await entorno.autorizar(b.v[0], reemplazos: [999])).estado, 422);
      expect((await entorno.autorizar(b.v[0], reemplazos: const [])).estado, 200, reason: 'puede dejarse sin pares');
    });
  });

  group('Generación con la cola y los pares (HU-07, HU-08)', () {
    test('la propuesta usa la unidad en turno o la siguiente, con su habitual o un reemplazo', () async {
      final b = await base();
      await entorno.servicio('S-001', b.ruta, '06:00', entrada: b.cola[0], capacidad: 12);
      final r = await entorno.generar();
      expect(r.estado, 201, reason: '$r');
      final a = Programacion.fromJson(r.mapa).asignaciones.single;
      expect(a.estado, EstadoAsignacion.asignado);
      expect(['V-01', 'V-02'], contains(a.codigoVehiculo));
      expect(a.saltoCola, a.codigoVehiculo != 'V-01');
      expect(a.codigoVehiculoCola, 'V-01');
      final habitual = a.codigoVehiculo == 'V-01' ? 'C-01' : 'C-02';
      expect([habitual, 'C-09'], contains(a.codigoConductor));
      expect(a.reemplazo, a.codigoConductor != habitual);
      expect(a.demoraMin, a.salida! - 360);
    });

    test('si la unidad en turno entra a mantenimiento sale la siguiente y se explica el salto', () async {
      final b = await base();
      await entorno.servicio('S-001', b.ruta, '06:00', entrada: b.cola[0], capacidad: 12);
      final v01 = await entorno.get('/api/vehiculos/${b.v[0]}', como: 'jdespacho');
      expect(
        (await entorno.put('/api/vehiculos/${b.v[0]}', {...v01.mapa, 'estado': 'mantenimiento'}, como: 'jdespacho')).estado,
        200,
      );
      final r = await entorno.generar();
      final a = Programacion.fromJson(r.mapa).asignaciones.single;
      expect(a.codigoVehiculo, 'V-02');
      expect(a.saltoCola, isTrue);
      expect(a.justificacion, contains('la unidad que corresponde (V-01) no está disponible'));

      // Al aprobar, la bitácora conserva el salto con su motivo (sección 3.6).
      expect((await entorno.post('/api/programaciones/${r.mapa['id']}/aprobar', null, como: 'operaciones')).estado, 200);
      final evento = (await entorno.consultar("SELECT detalle FROM bitacora WHERE accion = 'aprobar_programacion'")).single;
      final excepciones = (evento.json('detalle') as Map<String, Object?>)['excepciones'] as List<Object?>;
      final salto = excepciones.single as Map<String, Object?>;
      expect(salto['servicio'], 'S-001');
      expect(salto['saltoCola'], 'V-01');
      expect(salto['justificacion'], contains('no está disponible'));
    });

    test('si el habitual no cubre el turno, conduce un reemplazo autorizado y se explica', () async {
      final b = await base();
      await entorno.post('/api/cola/${b.cola[1]}/retirar', null, como: 'jdespacho');
      await entorno.post('/api/cola/${b.cola[2]}/retirar', null, como: 'jdespacho');
      final c01 = (await entorno.get('/api/conductores/${b.c['C-01']}', como: 'jdespacho')).mapa;
      await entorno.put('/api/conductores/${b.c['C-01']}', {...c01, 'turnoInicio': 600}, como: 'jdespacho');
      await entorno.servicio('S-001', b.ruta, '06:00', entrada: b.cola[0]);

      final a = Programacion.fromJson((await entorno.generar()).mapa).asignaciones.single;
      expect((a.codigoVehiculo, a.codigoConductor), ('V-01', 'C-09'));
      expect(a.reemplazo, isTrue);
      expect(a.codigoConductorHabitual, 'C-01');
      expect(a.justificacion, contains('el conductor habitual (C-01) no está disponible'));
    });

    test('una unidad sin conductores autorizados deja el servicio como incidencia con su motivo', () async {
      final b = await base();
      expect((await entorno.autorizar(b.v[0])).estado, 200);
      await entorno.post('/api/cola/${b.cola[1]}/retirar', null, como: 'jdespacho');
      await entorno.post('/api/cola/${b.cola[2]}/retirar', null, como: 'jdespacho');
      await entorno.servicio('S-001', b.ruta, '06:00', entrada: b.cola[0]);
      final a = Programacion.fromJson((await entorno.generar()).mapa).asignaciones.single;
      expect(a.estado, EstadoAsignacion.incidencia);
      expect(a.motivo, 'La unidad V-01 no tiene conductor habitual ni reemplazos autorizados registrados');
    });
  });

  group('Ajuste manual con la cola y los pares (HU-09)', () {
    test('se rechaza una unidad fuera de la cola o un conductor no autorizado; un salto exige motivo', () async {
      final b = await base();
      final id = await entorno.servicio('S-001', b.ruta, '06:00', entrada: b.cola[0], capacidad: 12);
      final p = Programacion.fromJson((await entorno.generar()).mapa);
      final ruta = '/api/programaciones/${p.id}/asignaciones/$id';
      Future<Respuesta> ajustar(int v, String c, {String? motivo}) => entorno.put(
            ruta,
            AjusteAsignacion(vehiculoId: v, conductorId: b.c[c]!, salida: 360, justificacion: motivo).toJson(),
            como: 'operaciones',
          );

      final fueraDeCola = await ajustar(b.v[2], 'C-03');
      expect(fueraDeCola.estado, 422);
      expect(fueraDeCola.mensajeError,
          'Por la regla de cola el servicio sale con la unidad que corresponde (V-01) o con la siguiente elegible (V-02)');

      final noAutorizado = await ajustar(b.v[0], 'C-02');
      expect(noAutorizado.estado, 422);
      expect(noAutorizado.mensajeError, 'El conductor C-02 no es el habitual ni un reemplazo autorizado de V-01');

      final sinMotivo = await ajustar(b.v[1], 'C-02');
      expect(sinMotivo.estado, 422);
      expect(sinMotivo.camposError['justificacion'], 'Indique el motivo: el ajuste salta la cola (correspondía V-01)');

      final conMotivo = await ajustar(b.v[1], 'C-09', motivo: 'V-01 con falla de frenos al salir');
      expect(conMotivo.estado, 200, reason: '$conMotivo');
      final a = Programacion.fromJson(conMotivo.mapa).asignaciones.single;
      expect((a.saltoCola, a.reemplazo, a.justificacion), (true, true, 'V-01 con falla de frenos al salir'));

      final volver = await ajustar(b.v[0], 'C-01');
      expect(volver.estado, 200, reason: 'volver a la alternativa preferente no exige motivo');
      final preferente = Programacion.fromJson(volver.mapa).asignaciones.single;
      expect((preferente.saltoCola, preferente.reemplazo, preferente.justificacion), (false, false, null));
    });
  });

  test('HU-11: el reporte suma los saltos de cola, los reemplazos y las demoras aprobados', () async {
    final b = await base();
    await entorno.servicio('S-001', b.ruta, '06:00', entrada: b.cola[0], capacidad: 12);
    final v01 = await entorno.get('/api/vehiculos/${b.v[0]}', como: 'jdespacho');
    await entorno.put('/api/vehiculos/${b.v[0]}', {...v01.mapa, 'estado': 'mantenimiento'}, como: 'jdespacho');
    final p = Programacion.fromJson((await entorno.generar()).mapa);
    expect((await entorno.post('/api/programaciones/${p.id}/aprobar', null, como: 'operaciones')).estado, 200);

    final r = await entorno.get('/api/reportes/indicadores?desde=${Entorno.turno}&hasta=${Entorno.turno}', como: 'operaciones');
    final reporte = ReporteIndicadores.fromJson(r.mapa);
    expect(reporte.saltosCola, 1);
    expect(reporte.reemplazos, p.reemplazos);
    expect(reporte.salidasDemoradas, p.salidasDemoradas);
    expect(reporte.minutosDemora, p.minutosDemora);
    expect(reporte.retrasoAcumuladoMin, p.componentes.retrasoMin);
    expect(reporte.tiempoMuertoMin, p.componentes.tiempoMuertoMin);
    final csv = await entorno.get('/api/reportes/indicadores.csv?desde=${Entorno.turno}&hasta=${Entorno.turno}', como: 'operaciones');
    expect(csv.texto, contains('Saltos de cola Σσ(s);1;servicios'));
  });
}
