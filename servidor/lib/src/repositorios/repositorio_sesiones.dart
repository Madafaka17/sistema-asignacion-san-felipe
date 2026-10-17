import '../infraestructura/base_datos.dart';

class SesionVigente {
  const SesionVigente(this.id, this.usuarioId);

  final int id;
  final int usuarioId;
}

/// Tokens de actualización emitidos (solo su resumen SHA-256).
abstract interface class RepositorioSesiones {
  Future<void> crear(int usuarioId, String hashToken, DateTime expiraEn);

  Future<SesionVigente?> buscarVigente(String hashToken, DateTime ahora);

  Future<void> revocar(int sesionId);
}

class RepositorioSesionesMysql implements RepositorioSesiones {
  const RepositorioSesionesMysql(this._bd);

  final BaseDatos _bd;

  @override
  Future<void> crear(int usuarioId, String hashToken, DateTime expiraEn) => _bd.ejecutar(
        'INSERT INTO sesion (usuario_id, hash_token, expira_en) VALUES (:usuario, :hash, :expira)',
        {'usuario': usuarioId, 'hash': hashToken, 'expira': expiraEn},
      );

  @override
  Future<SesionVigente?> buscarVigente(String hashToken, DateTime ahora) async {
    final filas = await _bd.consultar(
      'SELECT s.id, s.usuario_id FROM sesion s JOIN usuario u ON u.id = s.usuario_id '
      'WHERE s.hash_token = :hash AND NOT s.revocada AND s.expira_en > :ahora AND u.activo',
      {'hash': hashToken, 'ahora': ahora},
    );
    return filas.isEmpty ? null : SesionVigente(filas.single.entero('id'), filas.single.entero('usuario_id'));
  }

  @override
  Future<void> revocar(int sesionId) =>
      _bd.ejecutar('UPDATE sesion SET revocada = TRUE WHERE id = :id', {'id': sesionId});
}
