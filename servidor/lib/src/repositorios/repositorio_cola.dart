import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

/// Colas de despacho (tablas `cola` y `entrada_cola`): `π(s)` y `v0(s)`.
abstract interface class RepositorioCola {
  /// Entradas de las colas de la fecha, en el orden de llegada; con
  /// [rutaId], solo las de esa ruta.
  Future<List<EntradaCola>> entradas(DateTime fecha, {int? rutaId});

  Future<EntradaCola?> buscar(int id);

  /// Id de la cola de la ruta y fecha, que se crea si no existe, con su fila
  /// bloqueada hasta el final de la transacción: dos llegadas simultáneas no
  /// pueden recibir la misma posición.
  Future<int> bloquearCola(Ejecutor tx, int rutaId, DateTime fecha);

  /// Última entrada registrada en la cola (activa o no).
  Future<({int posicion, int llegada})?> ultima(Ejecutor tx, int colaId);

  /// Entrada activa de la unidad en alguna cola de la fecha que todavía no
  /// corresponde a ningún servicio: la unidad ya espera turno.
  Future<EntradaCola?> enEspera(Ejecutor tx, int vehiculoId, DateTime fecha);

  Future<int> insertar(Ejecutor tx, {required int colaId, required int vehiculoId, required int posicion, required int llegada, required int usuarioId});

  Future<void> retirar(int id, DateTime momento);
}

class RepositorioColaMysql implements RepositorioCola {
  const RepositorioColaMysql(this._bd);

  final BaseDatos _bd;

  static const _columnas = 'e.id, c.ruta_id, c.fecha, e.vehiculo_id, v.codigo AS vehiculo, e.posicion, e.llegada, '
      'e.activa, s.id AS servicio_id, s.codigo AS servicio';
  static const _desde = 'FROM entrada_cola e JOIN cola c ON c.id = e.cola_id JOIN vehiculo v ON v.id = e.vehiculo_id '
      'LEFT JOIN servicio s ON s.entrada_vigente = e.id';

  static EntradaCola _entrada(Fila f) => EntradaCola(
        id: f.entero('id'),
        rutaId: f.entero('ruta_id'),
        fecha: f.fecha('fecha'),
        vehiculoId: f.entero('vehiculo_id'),
        codigoVehiculo: f.texto('vehiculo'),
        posicion: f.entero('posicion'),
        llegada: f.entero('llegada'),
        activa: f.booleano('activa'),
        servicioId: f.enteroNulo('servicio_id'),
        codigoServicio: f.textoNulo('servicio'),
      );

  @override
  Future<List<EntradaCola>> entradas(DateTime fecha, {int? rutaId}) async => (await _bd.consultar(
        'SELECT $_columnas $_desde WHERE c.fecha = :fecha ${rutaId == null ? '' : 'AND c.ruta_id = :ruta'} '
        'ORDER BY c.ruta_id, e.posicion',
        {'fecha': formatoFecha(fecha), 'ruta': rutaId},
      ))
          .map(_entrada)
          .toList();

  @override
  Future<EntradaCola?> buscar(int id) async {
    final filas = await _bd.consultar('SELECT $_columnas $_desde WHERE e.id = :id', {'id': id});
    return filas.isEmpty ? null : _entrada(filas.single);
  }

  @override
  Future<int> bloquearCola(Ejecutor tx, int rutaId, DateTime fecha) async {
    final parametros = {'ruta': rutaId, 'fecha': formatoFecha(fecha)};
    await tx.ejecutar('INSERT IGNORE INTO cola (ruta_id, fecha) VALUES (:ruta, :fecha)', parametros);
    return (await tx.consultar('SELECT id FROM cola WHERE ruta_id = :ruta AND fecha = :fecha FOR UPDATE', parametros))
        .single
        .entero('id');
  }

  @override
  Future<({int posicion, int llegada})?> ultima(Ejecutor tx, int colaId) async {
    final filas = await tx.consultar(
      'SELECT posicion, llegada FROM entrada_cola WHERE cola_id = :cola ORDER BY posicion DESC LIMIT 1',
      {'cola': colaId},
    );
    return filas.isEmpty ? null : (posicion: filas.single.entero('posicion'), llegada: filas.single.entero('llegada'));
  }

  @override
  Future<EntradaCola?> enEspera(Ejecutor tx, int vehiculoId, DateTime fecha) async {
    final filas = await tx.consultar(
      'SELECT $_columnas $_desde WHERE e.vehiculo_id = :vehiculo AND c.fecha = :fecha AND e.activa AND s.id IS NULL '
      'ORDER BY e.id LIMIT 1',
      {'vehiculo': vehiculoId, 'fecha': formatoFecha(fecha)},
    );
    return filas.isEmpty ? null : _entrada(filas.single);
  }

  @override
  Future<int> insertar(
    Ejecutor tx, {
    required int colaId,
    required int vehiculoId,
    required int posicion,
    required int llegada,
    required int usuarioId,
  }) async =>
      (await tx.ejecutar(
        'INSERT INTO entrada_cola (cola_id, vehiculo_id, posicion, llegada, registrado_por) '
        'VALUES (:cola, :vehiculo, :posicion, :llegada, :usuario)',
        {'cola': colaId, 'vehiculo': vehiculoId, 'posicion': posicion, 'llegada': llegada, 'usuario': usuarioId},
      ))
          .idInsertado;

  @override
  Future<void> retirar(int id, DateTime momento) => _bd.ejecutar(
        'UPDATE entrada_cola SET activa = FALSE, retirada_en = :momento WHERE id = :id',
        {'id': id, 'momento': momento},
      );
}
