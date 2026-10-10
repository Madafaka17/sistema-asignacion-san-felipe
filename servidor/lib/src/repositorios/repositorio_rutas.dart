import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

/// Rutas, su compatibilidad con vehículos (κ, tabla `ruta_vehiculo`) y sus
/// salidas autorizadas (H_s).
abstract interface class RepositorioRutas {
  Future<List<Ruta>> todas();

  Future<Ruta?> buscar(int id);

  Future<bool> existeCodigo(String codigo, {int? excepto});

  Future<int> crear(Ruta ruta);

  Future<void> actualizar(Ruta ruta);

  Future<List<SalidaAutorizada>> salidas({int? rutaId});

  Future<SalidaAutorizada?> buscarSalida(int id);

  Future<bool> existeSalida(int rutaId, int hora);

  Future<int> crearSalida(SalidaAutorizada salida);

  Future<bool> salidaEnUso(SalidaAutorizada salida);

  Future<void> eliminarSalida(int id);
}

class RepositorioRutasMysql implements RepositorioRutas {
  const RepositorioRutasMysql(this._bd);

  final BaseDatos _bd;

  @override
  Future<List<Ruta>> todas() async {
    final filas = await _bd.consultar('SELECT id, codigo, origen, destino, duracion_min, activa FROM ruta ORDER BY codigo');
    final compatibles = <int, List<int>>{};
    for (final f in await _bd.consultar('SELECT ruta_id, vehiculo_id FROM ruta_vehiculo ORDER BY vehiculo_id')) {
      compatibles.putIfAbsent(f.entero('ruta_id'), () => []).add(f.entero('vehiculo_id'));
    }
    return [for (final f in filas) _ruta(f, compatibles[f.entero('id')] ?? const [])];
  }

  @override
  Future<Ruta?> buscar(int id) async {
    final filas = await _bd.consultar(
      'SELECT id, codigo, origen, destino, duracion_min, activa FROM ruta WHERE id = :id',
      {'id': id},
    );
    if (filas.isEmpty) return null;
    final compatibles = await _bd.consultar(
      'SELECT vehiculo_id FROM ruta_vehiculo WHERE ruta_id = :id ORDER BY vehiculo_id',
      {'id': id},
    );
    return _ruta(filas.single, [for (final f in compatibles) f.entero('vehiculo_id')]);
  }

  static Ruta _ruta(Fila f, List<int> compatibles) => Ruta(
        id: f.entero('id'),
        codigo: f.texto('codigo'),
        origen: f.texto('origen'),
        destino: f.texto('destino'),
        duracionMin: f.entero('duracion_min'),
        activa: f.booleano('activa'),
        vehiculosCompatibles: compatibles,
      );

  @override
  Future<bool> existeCodigo(String codigo, {int? excepto}) async => (await _bd.consultar(
        'SELECT 1 FROM ruta WHERE codigo = :codigo AND id <> :excepto',
        {'codigo': codigo, 'excepto': excepto ?? 0},
      ))
          .isNotEmpty;

  @override
  Future<int> crear(Ruta ruta) => _bd.transaccion((tx) async {
        final id = (await tx.ejecutar(
          'INSERT INTO ruta (codigo, origen, destino, duracion_min, activa) '
          'VALUES (:codigo, :origen, :destino, :duracion, :activa)',
          _parametros(ruta),
        ))
            .idInsertado;
        await _guardarCompatibles(tx, id, ruta.vehiculosCompatibles);
        return id;
      });

  @override
  Future<void> actualizar(Ruta ruta) => _bd.transaccion((tx) async {
        await tx.ejecutar(
          'UPDATE ruta SET codigo = :codigo, origen = :origen, destino = :destino, '
          'duracion_min = :duracion, activa = :activa WHERE id = :id',
          {..._parametros(ruta), 'id': ruta.id},
        );
        await tx.ejecutar('DELETE FROM ruta_vehiculo WHERE ruta_id = :id', {'id': ruta.id});
        await _guardarCompatibles(tx, ruta.id, ruta.vehiculosCompatibles);
      });

  static Future<void> _guardarCompatibles(Ejecutor tx, int rutaId, List<int> vehiculos) async {
    for (final v in vehiculos.toSet()) {
      await tx.ejecutar(
        'INSERT INTO ruta_vehiculo (ruta_id, vehiculo_id) VALUES (:ruta, :vehiculo)',
        {'ruta': rutaId, 'vehiculo': v},
      );
    }
  }

  static Map<String, Object?> _parametros(Ruta r) => {
        'codigo': r.codigo,
        'origen': r.origen,
        'destino': r.destino,
        'duracion': r.duracionMin,
        'activa': r.activa,
      };

  static SalidaAutorizada _salida(Fila f) => SalidaAutorizada(
        id: f.entero('id'),
        rutaId: f.entero('ruta_id'),
        hora: f.entero('hora'),
        duracionMin: f.enteroNulo('duracion_min'),
      );

  @override
  Future<List<SalidaAutorizada>> salidas({int? rutaId}) async => (await _bd.consultar(
        'SELECT id, ruta_id, hora, duracion_min FROM salida_autorizada '
        '${rutaId == null ? '' : 'WHERE ruta_id = :ruta'} ORDER BY ruta_id, hora',
        {'ruta': rutaId},
      ))
          .map(_salida)
          .toList();

  @override
  Future<SalidaAutorizada?> buscarSalida(int id) async {
    final filas = await _bd.consultar(
      'SELECT id, ruta_id, hora, duracion_min FROM salida_autorizada WHERE id = :id',
      {'id': id},
    );
    return filas.isEmpty ? null : _salida(filas.single);
  }

  @override
  Future<bool> existeSalida(int rutaId, int hora) async => (await _bd.consultar(
        'SELECT 1 FROM salida_autorizada WHERE ruta_id = :ruta AND hora = :hora',
        {'ruta': rutaId, 'hora': hora},
      ))
          .isNotEmpty;

  @override
  Future<int> crearSalida(SalidaAutorizada s) async => (await _bd.ejecutar(
        'INSERT INTO salida_autorizada (ruta_id, hora, duracion_min) VALUES (:ruta, :hora, :duracion)',
        {'ruta': s.rutaId, 'hora': s.hora, 'duracion': s.duracionMin},
      ))
          .idInsertado;

  @override
  Future<bool> salidaEnUso(SalidaAutorizada s) async => (await _bd.consultar(
        'SELECT 1 FROM servicio WHERE ruta_id = :ruta AND hora_solicitada = :hora LIMIT 1',
        {'ruta': s.rutaId, 'hora': s.hora},
      ))
          .isNotEmpty;

  @override
  Future<void> eliminarSalida(int id) => _bd.ejecutar('DELETE FROM salida_autorizada WHERE id = :id', {'id': id});
}
