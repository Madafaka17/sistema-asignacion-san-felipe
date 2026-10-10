import 'dart:convert';

import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

/// Bitácora de acciones (RNF-06): aprobaciones, ajustes, cambios de datos y
/// bloqueos de cuenta, con usuario, fecha y hora.
abstract interface class RepositorioBitacora {
  Future<void> registrar(
    Ejecutor ejecutor, {
    int? usuarioId,
    required String accion,
    required String entidad,
    int? entidadId,
    Map<String, Object?> detalle,
    required DateTime fechaHora,
  });

  Future<Pagina<EntradaBitacora>> listar(ParametrosPagina pagina, {String? accion, String? entidad, int? entidadId});
}

class RepositorioBitacoraMysql implements RepositorioBitacora {
  const RepositorioBitacoraMysql(this._bd);

  final BaseDatos _bd;

  @override
  Future<void> registrar(
    Ejecutor ejecutor, {
    int? usuarioId,
    required String accion,
    required String entidad,
    int? entidadId,
    Map<String, Object?> detalle = const {},
    required DateTime fechaHora,
  }) =>
      ejecutor.ejecutar(
        'INSERT INTO bitacora (usuario_id, accion, entidad, entidad_id, detalle, fecha_hora) '
        'VALUES (:usuario, :accion, :entidad, :entidadId, :detalle, :fechaHora)',
        {
          'usuario': usuarioId,
          'accion': accion,
          'entidad': entidad,
          'entidadId': entidadId,
          'detalle': jsonEncode(detalle),
          'fechaHora': fechaHora,
        },
      );

  @override
  Future<Pagina<EntradaBitacora>> listar(
    ParametrosPagina pagina, {
    String? accion,
    String? entidad,
    int? entidadId,
  }) async {
    final condiciones = [
      if (accion != null) 'b.accion = :accion',
      if (entidad != null) 'b.entidad = :entidad',
      if (entidadId != null) 'b.entidad_id = :entidadId',
    ];
    final donde = condiciones.isEmpty ? '' : 'WHERE ${condiciones.join(' AND ')}';
    final parametros = {'accion': accion, 'entidad': entidad, 'entidadId': entidadId};
    final total = (await _bd.consultar('SELECT COUNT(*) AS n FROM bitacora b $donde', parametros)).single.entero('n');
    final filas = await _bd.consultar(
      'SELECT b.id, u.nombre_usuario, b.accion, b.entidad, b.entidad_id, b.detalle, b.fecha_hora '
      'FROM bitacora b LEFT JOIN usuario u ON u.id = b.usuario_id $donde '
      'ORDER BY b.id DESC LIMIT :limite OFFSET :desde',
      {...parametros, 'limite': pagina.tamano, 'desde': pagina.desplazamiento},
    );
    return Pagina(
      elementos: [
        for (final f in filas)
          EntradaBitacora(
            id: f.entero('id'),
            usuario: f.textoNulo('nombre_usuario'),
            accion: f.texto('accion'),
            entidad: f.texto('entidad'),
            entidadId: f.enteroNulo('entidad_id'),
            detalle: (f.json('detalle') as Map?)?.cast<String, Object?>() ?? const {},
            fechaHora: f.fechaHora('fecha_hora'),
          ),
      ],
      total: total,
      pagina: pagina.pagina,
      tamano: pagina.tamano,
    );
  }
}
