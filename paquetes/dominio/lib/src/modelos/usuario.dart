import '../contrato/lector_json.dart';

/// Roles de la sección 3.1.9 de la tesis.
enum Rol {
  despacho('despacho', 'Personal de despacho'),
  operaciones('operaciones', 'Encargado de operaciones'),
  administrador('administrador', 'Administrador del sistema');

  const Rol(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static Rol desdeValor(String valor) => Rol.values.firstWhere((r) => r.valor == valor);
}

/// Módulos funcionales del sistema.
enum Modulo {
  vehiculos('Vehículos'),
  conductores('Conductores'),
  rutas('Rutas y salidas'),
  servicios('Servicios'),
  incidencias('Incidencias'),
  programacion('Programación'),
  reportes('Reportes'),
  usuarios('Usuarios'),
  parametros('Parámetros'),
  bitacora('Bitácora');

  const Modulo(this.etiqueta);

  final String etiqueta;
}

/// Matriz de permisos por rol (HU-01). El servidor la usa para autorizar
/// cada solicitud y el cliente para decidir qué módulos mostrar, de modo que
/// las dos capas no pueden discrepar.
class Permisos {
  static const _lectura = <Modulo, Set<Rol>>{
    Modulo.vehiculos: {Rol.despacho, Rol.operaciones},
    Modulo.conductores: {Rol.despacho, Rol.operaciones},
    Modulo.rutas: {Rol.despacho, Rol.operaciones},
    Modulo.servicios: {Rol.despacho, Rol.operaciones},
    Modulo.incidencias: {Rol.despacho, Rol.operaciones},
    Modulo.programacion: {Rol.operaciones},
    Modulo.reportes: {Rol.operaciones},
    Modulo.usuarios: {Rol.administrador},
    Modulo.parametros: {Rol.administrador},
    Modulo.bitacora: {Rol.administrador},
  };

  static const _escritura = <Modulo, Set<Rol>>{
    Modulo.vehiculos: {Rol.despacho},
    Modulo.conductores: {Rol.despacho},
    Modulo.rutas: {Rol.despacho},
    Modulo.servicios: {Rol.despacho},
    Modulo.incidencias: {Rol.despacho},
    Modulo.programacion: {Rol.operaciones},
    Modulo.reportes: {},
    Modulo.usuarios: {Rol.administrador},
    Modulo.parametros: {},
    Modulo.bitacora: {},
  };

  static bool puedeLeer(Rol rol, Modulo modulo) => _lectura[modulo]!.contains(rol);

  static bool puedeEscribir(Rol rol, Modulo modulo) => _escritura[modulo]!.contains(rol);

  /// Módulos que aparecen en la navegación de cada rol: el despacho ve los
  /// registros e incidencias; operaciones, la programación y los reportes; el
  /// administrador, los usuarios, los parámetros y la bitácora.
  static List<Modulo> modulosNavegacion(Rol rol) => switch (rol) {
        Rol.despacho => const [
            Modulo.servicios,
            Modulo.vehiculos,
            Modulo.conductores,
            Modulo.rutas,
            Modulo.incidencias,
          ],
        Rol.operaciones => const [Modulo.programacion, Modulo.reportes],
        Rol.administrador => const [Modulo.usuarios, Modulo.parametros, Modulo.bitacora],
      };
}

class Usuario {
  const Usuario({
    required this.id,
    required this.nombreUsuario,
    required this.nombreCompleto,
    required this.rol,
    this.activo = true,
  });

  final int id;
  final String nombreUsuario;
  final String nombreCompleto;
  final Rol rol;
  final bool activo;

  Map<String, Object?> toJson() => {
        'id': id,
        'nombreUsuario': nombreUsuario,
        'nombreCompleto': nombreCompleto,
        'rol': rol.valor,
        'activo': activo,
      };

  factory Usuario.fromJson(Map<String, Object?> json) {
    final l = LectorJson(json);
    final usuario = Usuario(
      id: l.entero('id'),
      nombreUsuario: l.texto('nombreUsuario'),
      nombreCompleto: l.texto('nombreCompleto'),
      rol: l.enumeracion('rol', Rol.values, (r) => r.valor),
      activo: l.booleano('activo'),
    );
    l.verificar();
    return usuario;
  }
}

/// Cuerpo de `POST /api/usuarios` (HU-01).
class SolicitudUsuario {
  const SolicitudUsuario({
    required this.nombreUsuario,
    required this.nombreCompleto,
    required this.rol,
    required this.contrasena,
  });

  final String nombreUsuario;
  final String nombreCompleto;
  final Rol rol;
  final String contrasena;

  Map<String, Object?> toJson() => {
        'nombreUsuario': nombreUsuario,
        'nombreCompleto': nombreCompleto,
        'rol': rol.valor,
        'contrasena': contrasena,
      };

  factory SolicitudUsuario.fromJson(Object? json) {
    final l = LectorJson(json);
    final solicitud = SolicitudUsuario(
      nombreUsuario: l.texto('nombreUsuario', maximo: 50),
      nombreCompleto: l.texto('nombreCompleto', maximo: 120),
      rol: l.enumeracion('rol', Rol.values, (r) => r.valor),
      contrasena: l.texto('contrasena', maximo: 128),
    );
    l.verificar();
    return solicitud;
  }
}

/// Respuesta de `POST /api/auth/ingresar` y `POST /api/auth/refrescar`.
///
/// El token de acceso viaja en el cuerpo y el cliente lo guarda solo en
/// memoria; el token de actualización viaja en una cookie `HttpOnly`.
class SesionIniciada {
  const SesionIniciada({
    required this.tokenAcceso,
    required this.expiraEnSegundos,
    required this.usuario,
  });

  final String tokenAcceso;
  final int expiraEnSegundos;
  final Usuario usuario;

  Map<String, Object?> toJson() => {
        'tokenAcceso': tokenAcceso,
        'expiraEnSegundos': expiraEnSegundos,
        'usuario': usuario.toJson(),
      };

  factory SesionIniciada.fromJson(Map<String, Object?> json) => SesionIniciada(
        tokenAcceso: json['tokenAcceso'] as String,
        expiraEnSegundos: json['expiraEnSegundos'] as int,
        usuario: Usuario.fromJson((json['usuario'] as Map).cast<String, Object?>()),
      );
}
