import 'dart:convert';

import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

/// Snapshots de la entrada (tabla `snapshot_entrada`): solo se insertan y se
/// leen. Una entrada idéntica (misma huella) reutiliza el snapshot existente.
abstract interface class RepositorioSnapshots {
  /// Guarda el [contenido] (JSON canónico) con su huella y devuelve su id.
  Future<int> registrar(Ejecutor tx, {required DateTime fecha, required String sha256, required String contenido});

  /// Snapshot con el que se construyó la programación [programacionId].
  Future<SnapshotEntrada?> deProgramacion(int programacionId);
}

class RepositorioSnapshotsMysql implements RepositorioSnapshots {
  const RepositorioSnapshotsMysql(this._bd);

  final BaseDatos _bd;

  @override
  Future<int> registrar(Ejecutor tx,
      {required DateTime fecha, required String sha256, required String contenido}) async {
    await tx.ejecutar(
      'INSERT IGNORE INTO snapshot_entrada (fecha, sha256, contenido) VALUES (:fecha, :sha, :contenido)',
      {'fecha': formatoFecha(fecha), 'sha': sha256, 'contenido': contenido},
    );
    return (await tx.consultar('SELECT id FROM snapshot_entrada WHERE sha256 = :sha', {'sha': sha256}))
        .single
        .entero('id');
  }

  @override
  Future<SnapshotEntrada?> deProgramacion(int programacionId) async {
    final filas = await _bd.consultar(
      'SELECT s.id, s.fecha, s.sha256, s.contenido, s.creado_en FROM snapshot_entrada s '
      'JOIN programacion p ON p.snapshot_id = s.id WHERE p.id = :id',
      {'id': programacionId},
    );
    if (filas.isEmpty) return null;
    final f = filas.single;
    return SnapshotEntrada(
      id: f.entero('id'),
      fecha: f.fecha('fecha'),
      sha256: f.texto('sha256'),
      contenido: (jsonDecode(f.texto('contenido')) as Map).cast<String, Object?>(),
      creadoEn: f.fechaHora('creado_en'),
    );
  }
}
