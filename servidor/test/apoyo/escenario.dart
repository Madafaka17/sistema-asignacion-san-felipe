import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

import 'entorno.dart';

/// Registro de datos de prueba por la API, como lo haría el personal de
/// despacho desde el cliente. Cada operación exige HTTP 201.
extension Escenario on Entorno {
  Future<Map<String, Object?>> _crear(String ruta, Map<String, Object?> cuerpo) async {
    final r = await post(ruta, cuerpo, como: 'jdespacho');
    expect(r.estado, 201, reason: 'POST $ruta: $r');
    return r.mapa;
  }

  Future<int> vehiculo(
    String codigo,
    String placa, {
    int capacidad = 15,
    String categoria = 'M2',
    String estado = 'operativo',
  }) async =>
      (await _crear('/api/vehiculos', {
        'codigo': codigo,
        'placa': placa,
        'capacidad': capacidad,
        'categoria': categoria,
        'estado': estado,
      }))['id'] as int;

  Future<int> conductor(
    String codigo,
    String dni, {
    String licencia = 'A-IIIa',
    String vence = '2027-06-30',
    String inicio = '06:00',
    String fin = '18:00',
    int acumulados = 0,
    int limite = 600,
    bool disponible = true,
  }) async =>
      (await _crear('/api/conductores', {
        'codigo': codigo,
        'dni': dni,
        'nombres': 'Conductor',
        'apellidos': 'De Prueba $codigo',
        'categoriaLicencia': licencia,
        'vencimientoLicencia': vence,
        'turnoInicio': horaAMinutos(inicio),
        'turnoFin': horaAMinutos(fin),
        'minutosAcumulados': acumulados,
        'limiteMinutos': limite,
        'disponible': disponible,
      }))['id'] as int;

  Future<int> ruta(String codigo, int duracion, List<int> vehiculos, {List<String> salidas = const []}) async {
    final id = (await _crear('/api/rutas', {
      'codigo': codigo,
      'origen': 'Soritor',
      'destino': 'Destino $codigo',
      'duracionMin': duracion,
      'activa': true,
      'vehiculosCompatibles': vehiculos,
    }))['id'] as int;
    for (final hora in salidas) {
      await salida(id, hora);
    }
    return id;
  }

  Future<int> salida(int rutaId, String hora) async =>
      (await _crear('/api/rutas/$rutaId/salidas', {'hora': horaAMinutos(hora)}))['id'] as int;

  Future<int> servicio(
    String codigo,
    int rutaId,
    String hora, {
    String fecha = Entorno.turno,
    int prioridad = 2,
    int capacidad = 1,
  }) async =>
      (await _crear('/api/servicios', {
        'codigo': codigo,
        'fecha': fecha,
        'rutaId': rutaId,
        'horaSolicitada': horaAMinutos(hora),
        'prioridad': prioridad,
        'capacidadRequerida': capacidad,
      }))['id'] as int;

  Future<Respuesta> generar([String fecha = Entorno.turno]) =>
      post('/api/programaciones', {'fecha': fecha}, como: 'operaciones');

  /// Turno de la Tabla 33 (HU-07): 3 vehículos, 3 conductores y 7 servicios
  /// pendientes el 12/11/2026 en tres rutas.
  Future<({List<int> vehiculos, List<int> conductores, List<int> rutas})> turnoBase() async {
    final v = [
      await vehiculo('V-01', 'AHK-101'),
      await vehiculo('V-02', 'AHK-102'),
      await vehiculo('V-03', 'AHK-103'),
    ];
    final c = [
      await conductor('C-01', '70000001'),
      await conductor('C-02', '70000002'),
      await conductor('C-03', '70000003'),
    ];
    final cadaMediaHora = [for (var m = 360; m <= 960; m += 30) minutosAHora(m)];
    final r = [
      await ruta('R-01', 50, v, salidas: cadaMediaHora),
      await ruta('R-02', 90, v, salidas: cadaMediaHora),
      await ruta('R-03', 95, v, salidas: cadaMediaHora),
    ];
    await servicio('S-101', r[0], '06:00', prioridad: 3);
    await servicio('S-102', r[1], '06:00', prioridad: 3);
    await servicio('S-103', r[2], '06:30');
    await servicio('S-104', r[0], '08:00');
    await servicio('S-105', r[1], '09:00');
    await servicio('S-106', r[2], '10:00', prioridad: 1);
    await servicio('S-107', r[0], '12:00', prioridad: 1);
    return (vehiculos: v, conductores: c, rutas: r);
  }
}

/// Asignaciones de una programación en el orden en que las devuelve la API.
List<Map<String, Object?>> asignacionesDe(Respuesta r) =>
    [for (final a in r.mapa['asignaciones'] as List<Object?>) a as Map<String, Object?>];

Map<String, Object?> asignacionDe(Respuesta r, String codigoServicio) =>
    asignacionesDe(r).firstWhere((a) => a['codigoServicio'] == codigoServicio);
