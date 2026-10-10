import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

/// Usuario con los datos de autenticación, que nunca salen del servidor.
class RegistroUsuario {
  const RegistroUsuario({
    required this.usuario,
    required this.hashContrasena,
    required this.intentosFallidos,
    this.bloqueadoHasta,
  });

  final Usuario usuario;
  final String hashContrasena;
  final int intentosFallidos;
  final DateTime? bloqueadoHasta;
}

abstract interface class RepositorioUsuarios {
  Future<RegistroUsuario?> buscarPorNombre(String nombreUsuario);

  Future<Usuario?> buscar(int id);

  Future<Pagina<Usuario>> listar(ParametrosPagina pagina);

  Future<bool> existeNombre(String nombreUsuario);

  Future<int> crear(SolicitudUsuario solicitud, String hashContrasena);

  Future<void> actualizarIntentos(int id, int intentos, DateTime? bloqueadoHasta);
}

class RepositorioUsuariosMysql implements RepositorioUsuarios {
  const RepositorioUsuariosMysql(this._bd);

  final BaseDatos _bd;

  static const _columnas = 'id, nombre_usuario, nombre_completo, rol, activo';

  static Usuario _usuario(Fila f) => Usuario(
        id: f.entero('id'),
        nombreUsuario: f.texto('nombre_usuario'),
        nombreCompleto: f.texto('nombre_completo'),
        rol: Rol.desdeValor(f.texto('rol')),
        activo: f.booleano('activo'),
      );

  @override
  Future<RegistroUsuario?> buscarPorNombre(String nombreUsuario) async {
    final filas = await _bd.consultar(
      'SELECT $_columnas, hash_contrasena, intentos_fallidos, bloqueado_hasta '
      'FROM usuario WHERE nombre_usuario = :nombre',
      {'nombre': nombreUsuario},
    );
    if (filas.isEmpty) return null;
    final f = filas.single;
    return RegistroUsuario(
      usuario: _usuario(f),
      hashContrasena: f.texto('hash_contrasena'),
      intentosFallidos: f.entero('intentos_fallidos'),
      bloqueadoHasta: f.fechaHoraNula('bloqueado_hasta'),
    );
  }

  @override
  Future<Usuario?> buscar(int id) async {
    final filas = await _bd.consultar('SELECT $_columnas FROM usuario WHERE id = :id', {'id': id});
    return filas.isEmpty ? null : _usuario(filas.single);
  }

  @override
  Future<Pagina<Usuario>> listar(ParametrosPagina pagina) async {
    final total = (await _bd.consultar('SELECT COUNT(*) AS n FROM usuario')).single.entero('n');
    final filas = await _bd.consultar(
      'SELECT $_columnas FROM usuario ORDER BY nombre_usuario LIMIT :limite OFFSET :desde',
      {'limite': pagina.tamano, 'desde': pagina.desplazamiento},
    );
    return Pagina(elementos: filas.map(_usuario).toList(), total: total, pagina: pagina.pagina, tamano: pagina.tamano);
  }

  @override
  Future<bool> existeNombre(String nombreUsuario) async => (await _bd.consultar(
        'SELECT 1 FROM usuario WHERE nombre_usuario = :nombre',
        {'nombre': nombreUsuario},
      ))
          .isNotEmpty;

  @override
  Future<int> crear(SolicitudUsuario solicitud, String hashContrasena) async => (await _bd.ejecutar(
        'INSERT INTO usuario (nombre_usuario, nombre_completo, hash_contrasena, rol) '
        'VALUES (:nombre, :completo, :hash, :rol)',
        {
          'nombre': solicitud.nombreUsuario,
          'completo': solicitud.nombreCompleto,
          'hash': hashContrasena,
          'rol': solicitud.rol.valor,
        },
      ))
          .idInsertado;

  @override
  Future<void> actualizarIntentos(int id, int intentos, DateTime? bloqueadoHasta) => _bd.ejecutar(
        'UPDATE usuario SET intentos_fallidos = :intentos, bloqueado_hasta = :hasta WHERE id = :id',
        {'id': id, 'intentos': intentos, 'hasta': bloqueadoHasta},
      );
}
