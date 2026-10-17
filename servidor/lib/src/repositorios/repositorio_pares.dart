import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

/// Pares autorizados unidad–conductor (tabla `par_autorizado`): `chab(v)` y
/// `C_v^R`.
abstract interface class RepositorioPares {
  Future<List<ParAutorizado>> todos();

  Future<ConductoresAutorizados> deVehiculo(int vehiculoId);

  /// Unidad de la que el conductor es habitual, si lo es.
  Future<int?> unidadHabitual(int conductorId);

  /// Reemplaza el conjunto completo de la unidad.
  Future<void> reemplazar(Ejecutor tx, ConductoresAutorizados autorizados);
}

class RepositorioParesMysql implements RepositorioPares {
  const RepositorioParesMysql(this._bd);

  final BaseDatos _bd;

  static ParAutorizado _par(Fila f) => ParAutorizado(
        vehiculoId: f.entero('vehiculo_id'),
        conductorId: f.entero('conductor_id'),
        tipo: TipoPar.desdeValor(f.texto('tipo')),
      );

  @override
  Future<List<ParAutorizado>> todos() async => (await _bd.consultar(
        'SELECT vehiculo_id, conductor_id, tipo FROM par_autorizado ORDER BY vehiculo_id, tipo, conductor_id',
      ))
          .map(_par)
          .toList();

  @override
  Future<ConductoresAutorizados> deVehiculo(int vehiculoId) async {
    final pares = (await _bd.consultar(
      'SELECT vehiculo_id, conductor_id, tipo FROM par_autorizado WHERE vehiculo_id = :v',
      {'v': vehiculoId},
    ))
        .map(_par);
    return ConductoresAutorizados.porVehiculo(pares)[vehiculoId] ?? ConductoresAutorizados(vehiculoId: vehiculoId);
  }

  @override
  Future<int?> unidadHabitual(int conductorId) async {
    final filas = await _bd.consultar(
      "SELECT vehiculo_id FROM par_autorizado WHERE conductor_id = :c AND tipo = 'habitual'",
      {'c': conductorId},
    );
    return filas.isEmpty ? null : filas.single.entero('vehiculo_id');
  }

  @override
  Future<void> reemplazar(Ejecutor tx, ConductoresAutorizados a) async {
    await tx.ejecutar('DELETE FROM par_autorizado WHERE vehiculo_id = :v', {'v': a.vehiculoId});
    for (final par in a.pares) {
      await tx.ejecutar(
        'INSERT INTO par_autorizado (vehiculo_id, conductor_id, tipo) VALUES (:v, :c, :tipo)',
        {'v': par.vehiculoId, 'c': par.conductorId, 'tipo': par.tipo.valor},
      );
    }
  }
}
