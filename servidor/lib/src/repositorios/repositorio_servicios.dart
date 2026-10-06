import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

abstract interface class RepositorioServicios {
  Future<Pagina<ServicioProgramado>> listar(ParametrosPagina pagina, {DateTime? fecha, EstadoServicio? estado});

  /// Servicios de la fecha con alguno de los [estados].
  Future<List<ServicioProgramado>> deFecha(DateTime fecha, Set<EstadoServicio> estados);

  Future<ServicioProgramado?> buscar(int id);

  Future<ServicioProgramado?> buscarPorCodigo(String codigo);

  Future<bool> existeCodigo(String codigo, {int? excepto});

  Future<int> crear(ServicioProgramado servicio, int? usuarioId);

  Future<void> actualizar(ServicioProgramado servicio);

  Future<void> cambiarEstado(Ejecutor ejecutor, Iterable<int> ids, EstadoServicio estado);
}

class RepositorioServiciosMysql implements RepositorioServicios {
  const RepositorioServiciosMysql(this._bd);

  final BaseDatos _bd;

  static const _columnas = 's.id, s.codigo, s.fecha, s.ruta_id, s.hora_solicitada, s.prioridad, '
      's.capacidad_requerida, s.estado, r.codigo AS codigo_ruta';
  static const _desde = 'FROM servicio s JOIN ruta r ON r.id = s.ruta_id';

  static ServicioProgramado _servicio(Fila f) => ServicioProgramado(
        id: f.entero('id'),
        codigo: f.texto('codigo'),
        fecha: f.fecha('fecha'),
        rutaId: f.entero('ruta_id'),
        horaSolicitada: f.entero('hora_solicitada'),
        prioridad: f.entero('prioridad'),
        capacidadRequerida: f.entero('capacidad_requerida'),
        estado: EstadoServicio.desdeValor(f.texto('estado')),
        codigoRuta: f.texto('codigo_ruta'),
      );

  @override
  Future<Pagina<ServicioProgramado>> listar(
    ParametrosPagina pagina, {
    DateTime? fecha,
    EstadoServicio? estado,
  }) async {
    final condiciones = [
      if (fecha != null) 's.fecha = :fecha',
      if (estado != null) 's.estado = :estado',
    ];
    final donde = condiciones.isEmpty ? '' : 'WHERE ${condiciones.join(' AND ')}';
    final parametros = {'fecha': fecha == null ? null : formatoFecha(fecha), 'estado': estado?.valor};
    final total = (await _bd.consultar('SELECT COUNT(*) AS n $_desde $donde', parametros)).single.entero('n');
    final filas = await _bd.consultar(
      'SELECT $_columnas $_desde $donde ORDER BY s.fecha, s.hora_solicitada, s.codigo '
      'LIMIT :limite OFFSET :desplazamiento',
      {...parametros, 'limite': pagina.tamano, 'desplazamiento': pagina.desplazamiento},
    );
    return Pagina(elementos: filas.map(_servicio).toList(), total: total, pagina: pagina.pagina, tamano: pagina.tamano);
  }

  @override
  Future<List<ServicioProgramado>> deFecha(DateTime fecha, Set<EstadoServicio> estados) async {
    if (estados.isEmpty) return const [];
    final marcadores = [for (var i = 0; i < estados.length; i++) ':e$i'].join(', ');
    final filas = await _bd.consultar(
      'SELECT $_columnas $_desde WHERE s.fecha = :fecha AND s.estado IN ($marcadores) '
      'ORDER BY s.hora_solicitada, s.codigo',
      {
        'fecha': formatoFecha(fecha),
        for (final (i, e) in estados.indexed) 'e$i': e.valor,
      },
    );
    return filas.map(_servicio).toList();
  }

  @override
  Future<ServicioProgramado?> buscar(int id) async {
    final filas = await _bd.consultar('SELECT $_columnas $_desde WHERE s.id = :id', {'id': id});
    return filas.isEmpty ? null : _servicio(filas.single);
  }

  @override
  Future<ServicioProgramado?> buscarPorCodigo(String codigo) async {
    final filas = await _bd.consultar('SELECT $_columnas $_desde WHERE s.codigo = :codigo', {'codigo': codigo});
    return filas.isEmpty ? null : _servicio(filas.single);
  }

  @override
  Future<bool> existeCodigo(String codigo, {int? excepto}) async => (await _bd.consultar(
        'SELECT 1 FROM servicio WHERE codigo = :codigo AND id <> :excepto',
        {'codigo': codigo, 'excepto': excepto ?? 0},
      ))
          .isNotEmpty;

  @override
  Future<int> crear(ServicioProgramado s, int? usuarioId) async => (await _bd.ejecutar(
        'INSERT INTO servicio (codigo, fecha, ruta_id, hora_solicitada, prioridad, capacidad_requerida, creado_por) '
        'VALUES (:codigo, :fecha, :ruta, :hora, :prioridad, :capacidad, :usuario)',
        {..._parametros(s), 'usuario': usuarioId},
      ))
          .idInsertado;

  @override
  Future<void> actualizar(ServicioProgramado s) => _bd.ejecutar(
        'UPDATE servicio SET codigo = :codigo, fecha = :fecha, ruta_id = :ruta, hora_solicitada = :hora, '
        'prioridad = :prioridad, capacidad_requerida = :capacidad, estado = :estado WHERE id = :id',
        {..._parametros(s), 'estado': s.estado.valor, 'id': s.id},
      );

  @override
  Future<void> cambiarEstado(Ejecutor ejecutor, Iterable<int> ids, EstadoServicio estado) async {
    final lista = ids.toList();
    if (lista.isEmpty) return;
    final marcadores = [for (var i = 0; i < lista.length; i++) ':s$i'].join(', ');
    await ejecutor.ejecutar(
      'UPDATE servicio SET estado = :estado WHERE id IN ($marcadores)',
      {'estado': estado.valor, for (final (i, id) in lista.indexed) 's$i': id},
    );
  }

  static Map<String, Object?> _parametros(ServicioProgramado s) => {
        'codigo': s.codigo,
        'fecha': formatoFecha(s.fecha),
        'ruta': s.rutaId,
        'hora': s.horaSolicitada,
        'prioridad': s.prioridad,
        'capacidad': s.capacidadRequerida,
      };
}
