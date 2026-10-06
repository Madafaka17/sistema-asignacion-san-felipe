import 'package:test/test.dart';

import '../apoyo/entorno.dart';
import '../apoyo/escenario.dart';

/// HU-02 a HU-06: registros de vehículos, conductores, rutas, salidas y
/// servicios (Tabla 33 de la tesis). La capa de lógica de negocio rechaza
/// los registros incompletos o inconsistentes antes de construir la
/// instancia del turno.
void main() {
  late Entorno entorno;

  setUpAll(() async => entorno = await Entorno.iniciar());
  setUp(() => entorno.reiniciar());
  tearDownAll(() => entorno.cerrar());

  group('HU-02 Vehículos', () {
    test('Registro de vehículo (feliz): V-07 con 15 asientos y estado operativo queda disponible', () async {
      final r = await entorno.post(
        '/api/vehiculos',
        {'codigo': 'V-07', 'placa': 'ABC-123', 'capacidad': 15, 'categoria': 'M2', 'estado': 'operativo'},
        como: 'jdespacho',
      );
      expect(r.estado, 201);
      expect(r.mapa, containsPair('codigo', 'V-07'));
      final operativos = await entorno.get('/api/vehiculos?estado=operativo', como: 'jdespacho');
      final codigos = [for (final v in operativos.mapa['elementos'] as List<Object?>) (v as Map)['codigo']];
      expect(codigos, contains('V-07'));
      final bitacora = await entorno.consultar("SELECT accion FROM bitacora WHERE entidad = 'vehiculo'");
      expect(bitacora.single.texto('accion'), 'crear_vehiculo');
    });

    test('Placa duplicada (error): se rechaza con «La placa ya está registrada»', () async {
      await entorno.vehiculo('V-07', 'ABC-123');
      final r = await entorno.post(
        '/api/vehiculos',
        {'codigo': 'V-08', 'placa': 'abc-123', 'capacidad': 15, 'categoria': 'M2', 'estado': 'operativo'},
        como: 'jdespacho',
      );
      expect(r.estado, 409);
      expect(r.mensajeError, 'La placa ya está registrada');
      expect(r.camposError, contains('placa'));
    });

    test('Unidad en mantenimiento (alterno): V-07 deja de figurar en las alternativas admisibles', () async {
      final v07 = await entorno.vehiculo('V-07', 'ABC-123');
      await entorno.conductor('C-01', '70000001');
      final ruta = await entorno.ruta('R-05', 60, [v07], salidas: ['07:00']);
      await entorno.servicio('S-201', ruta, '07:00');

      final antes = await entorno.generar();
      expect(antes.estado, 201);
      expect(asignacionDe(antes, 'S-201')['codigoVehiculo'], 'V-07');

      final cambio = await entorno.put(
        '/api/vehiculos/$v07',
        {'codigo': 'V-07', 'placa': 'ABC-123', 'capacidad': 15, 'categoria': 'M2', 'estado': 'mantenimiento'},
        como: 'jdespacho',
      );
      expect(cambio.estado, 200);

      final despues = await entorno.generar();
      expect(despues.estado, 201);
      final s201 = asignacionDe(despues, 'S-201');
      expect(s201['estado'], 'incidencia');
      expect(s201['vehiculoId'], isNull);
      expect(s201['motivo'], contains('no están operativos'));
    });

    test('Placa con formato inválido (422)', () async {
      final r = await entorno.post(
        '/api/vehiculos',
        {'codigo': 'V-09', 'placa': 'ABC123', 'capacidad': 15, 'categoria': 'M2', 'estado': 'operativo'},
        como: 'jdespacho',
      );
      expect(r.estado, 422);
      expect(r.camposError, contains('placa'));
    });
  });

  group('HU-03 Conductores', () {
    test('Registro de conductor (feliz): C-12 queda habilitado para los servicios de su turno', () async {
      final v = await entorno.vehiculo('V-01', 'AHK-101');
      final c12 = await entorno.conductor('C-12', '70000012', vence: '2027-06-30', inicio: '06:00', fin: '16:00');
      final ruta = await entorno.ruta('R-01', 50, [v], salidas: ['06:00', '17:00']);
      await entorno.servicio('S-301', ruta, '06:00');
      // 17:00 queda fuera del turno de C-12 (06:00–16:00).
      await entorno.servicio('S-302', ruta, '17:00');

      final r = await entorno.generar();
      expect(r.estado, 201);
      expect(asignacionDe(r, 'S-301')['conductorId'], c12);
      expect(asignacionDe(r, 'S-302')['estado'], 'incidencia');
      expect(asignacionDe(r, 'S-302')['motivo'], contains('turno'));
    });

    test('Licencia vencida (error): no se puede marcar disponible y se muestra «Licencia vencida»', () async {
      final c12 = await entorno.conductor('C-12', '70000012', vence: '2026-09-15', disponible: false);
      final r = await entorno.put('/api/conductores/$c12/disponibilidad', {'disponible': true}, como: 'jdespacho');
      expect(r.estado, 422);
      expect(r.mensajeError, 'Licencia vencida');
      final fila = (await entorno.consultar('SELECT disponible FROM conductor WHERE id = :id', {'id': c12})).single;
      expect(fila.booleano('disponible'), isFalse);
    });

    test('Límite de conducción (alterno): un servicio de 90 min que llevaría a C-12 sobre su límite es incidencia', () async {
      final v = await entorno.vehiculo('V-01', 'AHK-101');
      await entorno.conductor('C-12', '70000012', acumulados: 540, limite: 600);
      final ruta = await entorno.ruta('R-02', 90, [v], salidas: ['08:00']);
      await entorno.servicio('S-303', ruta, '08:00');

      final r = await entorno.generar();
      expect(r.estado, 201);
      final s = asignacionDe(r, 'S-303');
      expect(s['estado'], 'incidencia');
      expect(s['conductorId'], isNull);
      expect(s['motivo'], contains('límite de conducción de C-12'));
      expect(r.mapa['phiValidador'], 0);
    });

    test('DNI duplicado (409)', () async {
      await entorno.conductor('C-01', '70000001');
      final r = await entorno.post(
        '/api/conductores',
        {
          'codigo': 'C-02',
          'dni': '70000001',
          'nombres': 'Otro',
          'apellidos': 'Conductor',
          'categoriaLicencia': 'A-IIb',
          'vencimientoLicencia': '2027-01-01',
          'turnoInicio': 360,
          'turnoFin': 960,
          'minutosAcumulados': 0,
          'limiteMinutos': 600,
          'disponible': true,
        },
        como: 'jdespacho',
      );
      expect(r.estado, 409);
      expect(r.camposError, contains('dni'));
    });
  });

  group('HU-04 Rutas', () {
    test('Registro de ruta (feliz): R-03 de 95 min; el término es la salida más 95 min', () async {
      final v = await entorno.vehiculo('V-01', 'AHK-101');
      await entorno.conductor('C-01', '70000001');
      final r = await entorno.post(
        '/api/rutas',
        {
          'codigo': 'R-03',
          'origen': 'Soritor',
          'destino': 'Rioja',
          'duracionMin': 95,
          'activa': true,
          'vehiculosCompatibles': [v],
        },
        como: 'jdespacho',
      );
      expect(r.estado, 201);
      final ruta = r.mapa['id'] as int;
      await entorno.salida(ruta, '07:30');
      await entorno.servicio('S-115', ruta, '07:30', prioridad: 3);

      final p = await entorno.generar();
      final s = asignacionDe(p, 'S-115');
      expect(s['salida'], 450); // 07:30
      expect(s['fin'], 545); // 09:05 = 07:30 + 95 min
    });

    test('Duración inválida (error): «La duración debe ser mayor que cero»', () async {
      final r = await entorno.post(
        '/api/rutas',
        {'codigo': 'R-09', 'origen': 'A', 'destino': 'B', 'duracionMin': 0, 'activa': true, 'vehiculosCompatibles': <int>[]},
        como: 'jdespacho',
      );
      expect(r.estado, 422);
      expect(r.mensajeError, 'La duración debe ser mayor que cero');
      expect(r.camposError, contains('duracionMin'));
    });
  });

  group('HU-05 Salidas autorizadas', () {
    test('Registro de salida (feliz): 07:30 aparece como opción de salida de R-03', () async {
      final ruta = await entorno.ruta('R-03', 95, const []);
      final r = await entorno.post('/api/rutas/$ruta/salidas', {'hora': 450}, como: 'jdespacho');
      expect(r.estado, 201);
      final salidas = await entorno.get('/api/rutas/$ruta/salidas', como: 'jdespacho');
      expect([for (final s in salidas.lista) (s as Map)['hora']], [450]);
    });

    test('Salida duplicada (error): «La salida ya existe para esta ruta»', () async {
      final ruta = await entorno.ruta('R-03', 95, const [], salidas: ['07:30']);
      final r = await entorno.post('/api/rutas/$ruta/salidas', {'hora': 450}, como: 'jdespacho');
      expect(r.estado, 409);
      expect(r.mensajeError, 'La salida ya existe para esta ruta');
    });
  });

  group('HU-06 Servicios', () {
    test('Registro de servicio (feliz): S-115 del 12/11/2026 a las 07:30 con prioridad 3 queda pendiente', () async {
      final ruta = await entorno.ruta('R-03', 95, const [], salidas: ['07:30']);
      final r = await entorno.post(
        '/api/servicios',
        {'codigo': 'S-115', 'fecha': '2026-11-12', 'rutaId': ruta, 'horaSolicitada': 450, 'prioridad': 3, 'capacidadRequerida': 10},
        como: 'jdespacho',
      );
      expect(r.estado, 201);
      expect(r.mapa['estado'], 'pendiente');
      final pendientes = await entorno.get('/api/servicios?fecha=2026-11-12&estado=pendiente', como: 'jdespacho');
      final codigos = [for (final s in pendientes.mapa['elementos'] as List<Object?>) (s as Map)['codigo']];
      expect(codigos, ['S-115']);
    });

    test('Servicio sin ruta (error): se impide guardar y se resalta el campo «Ruta»', () async {
      final r = await entorno.post(
        '/api/servicios',
        {'codigo': 'S-116', 'fecha': '2026-11-12', 'horaSolicitada': 450, 'prioridad': 2, 'capacidadRequerida': 4},
        como: 'jdespacho',
      );
      expect(r.estado, 400);
      expect(r.camposError.keys, ['rutaId']);
      expect((await entorno.consultar('SELECT COUNT(*) AS n FROM servicio')).single.entero('n'), 0);
    });

    test('Hora fuera de las salidas autorizadas (422)', () async {
      final ruta = await entorno.ruta('R-03', 95, const [], salidas: ['07:30']);
      final r = await entorno.post(
        '/api/servicios',
        {'codigo': 'S-117', 'fecha': '2026-11-12', 'rutaId': ruta, 'horaSolicitada': 455, 'prioridad': 2, 'capacidadRequerida': 4},
        como: 'jdespacho',
      );
      expect(r.estado, 422);
      expect(r.camposError, contains('horaSolicitada'));
    });
  });
}
