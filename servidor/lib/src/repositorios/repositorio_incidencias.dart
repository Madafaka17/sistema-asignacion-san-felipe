import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

class NuevaIncidencia {
  const NuevaIncidencia({
    required this.servicioId,
    required this.tipo,
    required this.fecha,
    required this.hora,
    this.minutosRetraso,
    required this.descripcion,
    this.vehiculoId,
    this.conductorId,
    required this.registradoPor,
  });

  final int servicioId;
  final TipoIncidencia tipo;
  final DateTime fecha;
  final int hora;
  final int? minutosRetraso;
  final String descripcion;
  final int? vehiculoId;
  final int? conductorId;
  final int registradoPor;
}

abstract interface class RepositorioIncidencias {
  Future<int> crear(Ejecutor ejecutor, NuevaIncidencia incidencia);

  Future<Incidencia?> buscar(int id);

  Future<Pagina<Incidencia>> listar(ParametrosPagina pagina, {DateTime? desde, DateTime? hasta});
}

class RepositorioIncidenciasMysql implements RepositorioIncidencias {
  const RepositorioIncidenciasMysql(this._bd);

  final BaseDatos _bd;

  static const _consulta =
      'SELECT i.id, i.servicio_id, s.codigo AS servicio, i.tipo, i.fecha, i.hora, i.minutos_retraso, '
      'i.descripcion, i.vehiculo_id, v.codigo AS vehiculo, i.conductor_id, c.codigo AS conductor, '
      'u.nombre_usuario FROM incidencia i JOIN servicio s ON s.id = i.servicio_id '
      'LEFT JOIN vehiculo v ON v.id = i.vehiculo_id LEFT JOIN conductor c ON c.id = i.conductor_id '
      'LEFT JOIN usuario u ON u.id = i.registrado_por';

  static Incidencia _incidencia(Fila f) => Incidencia(
        id: f.entero('id'),
        servicioId: f.entero('servicio_id'),
        codigoServicio: f.texto('servicio'),
        tipo: TipoIncidencia.desdeValor(f.texto('tipo')),
        fecha: f.fecha('fecha'),
        hora: f.entero('hora'),
        minutosRetraso: f.enteroNulo('minutos_retraso'),
        descripcion: f.texto('descripcion'),
        vehiculoId: f.enteroNulo('vehiculo_id'),
        codigoVehiculo: f.textoNulo('vehiculo'),
        conductorId: f.enteroNulo('conductor_id'),
        codigoConductor: f.textoNulo('conductor'),
        registradoPor: f.textoNulo('nombre_usuario'),
      );

  @override
  Future<int> crear(Ejecutor tx, NuevaIncidencia i) async => (await tx.ejecutar(
        'INSERT INTO incidencia (servicio_id, tipo, fecha, hora, minutos_retraso, descripcion, vehiculo_id, '
        'conductor_id, registrado_por) VALUES (:servicio, :tipo, :fecha, :hora, :retraso, :descripcion, '
        ':vehiculo, :conductor, :usuario)',
        {
          'servicio': i.servicioId,
          'tipo': i.tipo.valor,
          'fecha': formatoFecha(i.fecha),
          'hora': i.hora,
          'retraso': i.minutosRetraso,
          'descripcion': i.descripcion,
          'vehiculo': i.vehiculoId,
          'conductor': i.conductorId,
          'usuario': i.registradoPor,
        },
      ))
          .idInsertado;

  @override
  Future<Incidencia?> buscar(int id) async {
    final filas = await _bd.consultar('$_consulta WHERE i.id = :id', {'id': id});
    return filas.isEmpty ? null : _incidencia(filas.single);
  }

  @override
  Future<Pagina<Incidencia>> listar(ParametrosPagina pagina, {DateTime? desde, DateTime? hasta}) async {
    final condiciones = [if (desde != null) 'i.fecha >= :desde', if (hasta != null) 'i.fecha <= :hasta'];
    final donde = condiciones.isEmpty ? '' : 'WHERE ${condiciones.join(' AND ')}';
    final parametros = {
      'desde': desde == null ? null : formatoFecha(desde),
      'hasta': hasta == null ? null : formatoFecha(hasta),
    };
    final total = (await _bd.consultar('SELECT COUNT(*) AS n FROM incidencia i $donde', parametros)).single.entero('n');
    final filas = await _bd.consultar(
      '$_consulta $donde ORDER BY i.fecha DESC, i.hora DESC, i.id DESC LIMIT :limite OFFSET :desplazamiento',
      {...parametros, 'limite': pagina.tamano, 'desplazamiento': pagina.desplazamiento},
    );
    return Pagina(elementos: filas.map(_incidencia).toList(), total: total, pagina: pagina.pagina, tamano: pagina.tamano);
  }
}
