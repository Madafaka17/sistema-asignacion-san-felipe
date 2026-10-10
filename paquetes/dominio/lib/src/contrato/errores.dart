/// Errores del contrato de la API. El servidor los lanza y el cliente los
/// reconstruye a partir de la respuesta, de modo que ambos usan los mismos
/// códigos y mensajes.
enum CodigoError {
  /// El cuerpo no tiene la forma o los tipos esperados (HTTP 400).
  solicitudInvalida('solicitud_invalida', 400),

  /// Falta la sesión o el token no es válido (HTTP 401).
  noAutenticado('no_autenticado', 401),

  /// El rol del usuario no puede usar el recurso (HTTP 403).
  prohibido('prohibido', 403),

  /// El recurso no existe (HTTP 404).
  noEncontrado('no_encontrado', 404),

  /// Choca con datos existentes, por ejemplo una placa repetida (HTTP 409).
  conflicto('conflicto', 409),

  /// Incumple una regla de negocio (HTTP 422).
  reglaNegocio('regla_negocio', 422),

  /// Cuenta bloqueada temporalmente (HTTP 423).
  bloqueado('bloqueado', 423),

  /// El cliente usa una versión del contrato que el servidor no admite
  /// (HTTP 426): debe actualizarse.
  versionIncompatible('version_incompatible', 426),

  /// Error inesperado del servidor (HTTP 500).
  interno('interno', 500);

  const CodigoError(this.valor, this.estadoHttp);

  final String valor;
  final int estadoHttp;

  static CodigoError desdeValor(String valor) => CodigoError.values.firstWhere(
        (c) => c.valor == valor,
        orElse: () => CodigoError.interno,
      );
}

/// Excepción con la que el servidor responde un error y el cliente lo recibe.
class ExcepcionApi implements Exception {
  ExcepcionApi(this.codigo, this.mensaje, {Map<String, String>? campos})
      : campos = Map.unmodifiable(campos ?? const {});

  final CodigoError codigo;
  final String mensaje;

  /// Errores por campo del formulario: nombre del campo → mensaje.
  final Map<String, String> campos;

  int get estadoHttp => codigo.estadoHttp;

  Map<String, Object?> toJson() => {
        'error': {
          'codigo': codigo.valor,
          'mensaje': mensaje,
          if (campos.isNotEmpty) 'campos': campos,
        },
      };

  /// Reconstruye el error a partir del cuerpo de una respuesta de error.
  factory ExcepcionApi.fromJson(Map<String, Object?> json) {
    final error = json['error'];
    if (error is! Map) {
      return ExcepcionApi(CodigoError.interno, 'Respuesta de error no reconocida');
    }
    final campos = error['campos'];
    return ExcepcionApi(
      CodigoError.desdeValor(error['codigo']?.toString() ?? ''),
      error['mensaje']?.toString() ?? 'Error desconocido',
      campos: campos is Map
          ? {for (final e in campos.entries) e.key.toString(): e.value.toString()}
          : null,
    );
  }

  @override
  String toString() => 'ExcepcionApi(${codigo.valor}): $mensaje'
      '${campos.isEmpty ? '' : ' $campos'}';
}
