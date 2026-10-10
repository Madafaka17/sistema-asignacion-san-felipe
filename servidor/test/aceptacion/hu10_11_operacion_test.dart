import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

import '../apoyo/entorno.dart';
import '../apoyo/escenario.dart';

/// HU-10 (incidencias) y HU-11 (reporte de indicadores, ecuaciones 19 a 23).
void main() {
  late Entorno entorno;

  setUpAll(() async => entorno = await Entorno.iniciar());
  setUp(() => entorno.reiniciar());
  tearDownAll(() => entorno.cerrar());

  group('HU-10 Incidencias', () {
    test('(feliz) un retraso de 25 min por «tráfico» queda asociado a S-115, a su vehículo y a su conductor', () async {
      final v07 = await entorno.vehiculo('V-07', 'ABC-123');
      final c12 = await entorno.conductor('C-12', '70000012');
      final ruta = await entorno.ruta('R-03', 95, [v07], salidas: ['07:30']);
      await entorno.servicio('S-115', ruta, '07:30', prioridad: 3);
      final propuesta = await entorno.generar();
      expect((await entorno.post('/api/programaciones/${propuesta.mapa['id']}/aprobar', null, como: 'operaciones')).estado, 200);

      final r = await entorno.post(
        '/api/incidencias',
        const {
          'codigoServicio': 'S-115',
          'tipo': 'retraso',
          'fecha': '2026-11-12',
          'hora': 480,
          'minutosRetraso': 25,
          'descripcion': 'tráfico',
        },
        como: 'jdespacho',
      );
      expect(r.estado, 201, reason: '$r');
      final incidencia = Incidencia.fromJson(r.mapa);
      expect(incidencia.codigoServicio, 'S-115');
      expect(incidencia.vehiculoId, v07);
      expect(incidencia.conductorId, c12);
      expect(incidencia.minutosRetraso, 25);

      final fila = (await entorno.consultar('SELECT descripcion, vehiculo_id, conductor_id FROM incidencia')).single;
      expect(fila.texto('descripcion'), 'tráfico');
      expect(fila.entero('vehiculo_id'), v07);
    });

    test('(error) servicio inexistente S-999: «Servicio no encontrado»', () async {
      final r = await entorno.post(
        '/api/incidencias',
        const {'codigoServicio': 'S-999', 'tipo': 'retraso', 'fecha': '2026-11-12', 'hora': 480, 'minutosRetraso': 10, 'descripcion': 'x'},
        como: 'jdespacho',
      );
      expect(r.estado, 404);
      expect(r.mensajeError, 'Servicio no encontrado');
      expect((await entorno.consultar('SELECT COUNT(*) AS n FROM incidencia')).single.entero('n'), 0);
    });

    test('una indisponibilidad del vehículo devuelve el servicio a pendiente para reprogramarlo', () async {
      final v07 = await entorno.vehiculo('V-07', 'ABC-123');
      await entorno.vehiculo('V-08', 'ABC-124');
      await entorno.conductor('C-12', '70000012');
      final ruta = await entorno.ruta('R-03', 95, [v07], salidas: ['07:30']);
      await entorno.servicio('S-115', ruta, '07:30');
      final propuesta = await entorno.generar();
      await entorno.post('/api/programaciones/${propuesta.mapa['id']}/aprobar', null, como: 'operaciones');

      final r = await entorno.post(
        '/api/incidencias',
        const {'codigoServicio': 'S-115', 'tipo': 'indisponibilidad_vehiculo', 'fecha': '2026-11-12', 'hora': 420, 'descripcion': 'falla mecánica'},
        como: 'jdespacho',
      );
      expect(r.estado, 201);
      final estado = (await entorno.consultar("SELECT estado FROM servicio WHERE codigo = 'S-115'")).single;
      expect(estado.texto('estado'), 'pendiente');
    });
  });

  group('HU-11 Reporte de indicadores', () {
    test('(feliz) noviembre de 2026: 190 servicios, 12 reprogramados y 9 con retraso → PSR = 6.3 % y PSA = 4.7 %', () async {
      await _noviembre(entorno, servicios: 190, reprogramados: 12, conRetraso: 9);

      final r = await entorno.get('/api/reportes/indicadores?desde=2026-11-01&hasta=2026-11-30', como: 'operaciones');
      expect(r.estado, 200);
      final reporte = ReporteIndicadores.fromJson(r.mapa);
      expect(reporte.sinDatos, isFalse);
      expect(reporte.serviciosProgramados, 190);
      expect(Indicadores.redondear(reporte.psr), 6.3);
      expect(Indicadores.redondear(reporte.psa), 4.7);
      expect(reporte.pio, 0);
      expect(reporte.pav, 100);
      expect(reporte.puv, greaterThan(0));

      final csv = await entorno.get('/api/reportes/indicadores.csv?desde=2026-11-01&hasta=2026-11-30', como: 'operaciones');
      expect(csv.estado, 200);
      expect(csv.cabeceras['content-type'], startsWith('text/csv'));
      expect(csv.cabeceras['content-disposition'], contains('indicadores_2026-11-01_2026-11-30.csv'));
      expect(csv.texto, contains('Porcentaje de servicios reprogramados (PSR);6.3;%'));
      expect(csv.texto, contains('Porcentaje de servicios con retraso (PSA);4.7;%'));
    });

    test('(alterno) periodo sin programaciones: «Sin datos para el periodo» y sin indicadores', () async {
      final r = await entorno.get('/api/reportes/indicadores?desde=2026-12-01&hasta=2026-12-31', como: 'operaciones');
      expect(r.estado, 200);
      expect(r.mapa['sinDatos'], isTrue);
      expect(r.mapa['mensaje'], 'Sin datos para el periodo');
    });

    test('periodo invertido o sin fechas (422/400)', () async {
      expect((await entorno.get('/api/reportes/indicadores?desde=2026-12-31&hasta=2026-12-01', como: 'operaciones')).estado, 422);
      final sinFechas = await entorno.get('/api/reportes/indicadores', como: 'operaciones');
      expect(sinFechas.estado, 400);
      expect(sinFechas.camposError, contains('desde'));
    });
  });
}

/// Historial de noviembre de 2026 cargado directamente en MySQL: 19 días con
/// una programación aprobada de 10 servicios cada uno.
Future<void> _noviembre(Entorno entorno, {required int servicios, required int reprogramados, required int conRetraso}) async {
  final v = await entorno.vehiculo('V-01', 'AHK-101');
  final c = await entorno.conductor('C-01', '70000001');
  final ruta = await entorno.ruta('R-01', 50, [v], salidas: [for (var h = 6; h < 16; h++) '${h.toString().padLeft(2, '0')}:00']);
  final ids = <int>[];
  await entorno.bd.transaccion((tx) async {
    for (var i = 0; i < servicios; i++) {
      final dia = 1 + i ~/ 10;
      final fecha = '2026-11-${dia.toString().padLeft(2, '0')}';
      final hora = (6 + i % 10) * 60;
      if (i % 10 == 0) {
        await tx.ejecutar(
          'INSERT INTO programacion (fecha, estado, metodo, aptitud, phi, phi_validador, tiempo_ms, vehiculos_disponibles, parametros) '
          "VALUES (:f, 'aprobada', 'algoritmo_genetico', -0.1, 0, 0, 150, 1, '{}')",
          {'f': fecha},
        );
      }
      final servicio = await tx.ejecutar(
        'INSERT INTO servicio (codigo, fecha, ruta_id, hora_solicitada, prioridad, capacidad_requerida, estado) '
        "VALUES (:c, :f, :r, :h, 2, 1, 'programado')",
        {'c': 'S-${(i + 1).toString().padLeft(3, '0')}', 'f': fecha, 'r': ruta, 'h': hora},
      );
      ids.add(servicio.idInsertado);
      await tx.ejecutar(
        'INSERT INTO asignacion (programacion_id, servicio_id, vehiculo_id, conductor_id, salida, fin, estado) '
        "SELECT MAX(id), :s, :v, :c, :h, :h + 50, 'asignado' FROM programacion",
        {'s': servicio.idInsertado, 'v': v, 'c': c, 'h': hora},
      );
    }
    Future<void> incidencia(int servicioId, String tipo, int? minutos) => tx.ejecutar(
          'INSERT INTO incidencia (servicio_id, tipo, fecha, hora, minutos_retraso, descripcion) '
          'SELECT id, :t, fecha, hora_solicitada, :m, :d FROM servicio WHERE id = :s',
          {'s': servicioId, 't': tipo, 'm': minutos, 'd': 'registro histórico'},
        );
    for (var i = 0; i < reprogramados; i++) {
      await incidencia(ids[i * 3], 'reprogramacion', null);
    }
    for (var i = 0; i < conRetraso; i++) {
      await incidencia(ids[i * 5 + 1], 'retraso', 15);
    }
  });
}
