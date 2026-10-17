/// Registro de la bitácora (sección 3.6 y RNF-06): quién hizo qué y cuándo.
class EntradaBitacora {
  const EntradaBitacora({
    required this.id,
    this.usuario,
    required this.accion,
    required this.entidad,
    this.entidadId,
    this.detalle = const {},
    required this.fechaHora,
  });

  final int id;
  final String? usuario;

  /// Por ejemplo `aprobar_programacion`, `ajustar_asignacion` o
  /// `bloqueo_cuenta`.
  final String accion;
  final String entidad;
  final int? entidadId;
  final Map<String, Object?> detalle;
  final DateTime fechaHora;

  Map<String, Object?> toJson() => {
        'id': id,
        'usuario': usuario,
        'accion': accion,
        'entidad': entidad,
        'entidadId': entidadId,
        'detalle': detalle,
        'fechaHora': fechaHora.toIso8601String(),
      };

  factory EntradaBitacora.fromJson(Map<String, Object?> json) => EntradaBitacora(
        id: json['id'] as int,
        usuario: json['usuario'] as String?,
        accion: json['accion'] as String,
        entidad: json['entidad'] as String,
        entidadId: json['entidadId'] as int?,
        detalle: (json['detalle'] as Map?)?.cast<String, Object?>() ?? const {},
        fechaHora: DateTime.parse(json['fechaHora'] as String),
      );
}
