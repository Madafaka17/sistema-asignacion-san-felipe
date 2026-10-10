import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

abstract interface class RepositorioVehiculos {
  Future<Pagina<Vehiculo>> listar(ParametrosPagina pagina, {EstadoVehiculo? estado});

  Future<List<Vehiculo>> todos();

  Future<Vehiculo?> buscar(int id);

  Future<bool> existePlaca(String placa, {int? excepto});

  Future<bool> existeCodigo(String codigo, {int? excepto});

  Future<int> crear(Vehiculo vehiculo);

  Future<void> actualizar(Vehiculo vehiculo);
}

class RepositorioVehiculosMysql implements RepositorioVehiculos {
  const RepositorioVehiculosMysql(this._bd);

  final BaseDatos _bd;

  static const _columnas = 'id, codigo, placa, capacidad, categoria, estado';

  static Vehiculo _vehiculo(Fila f) => Vehiculo(
        id: f.entero('id'),
        codigo: f.texto('codigo'),
        placa: f.texto('placa'),
        capacidad: f.entero('capacidad'),
        categoria: CategoriaVehiculo.desdeValor(f.texto('categoria')),
        estado: EstadoVehiculo.desdeValor(f.texto('estado')),
      );

  @override
  Future<Pagina<Vehiculo>> listar(ParametrosPagina pagina, {EstadoVehiculo? estado}) async {
    final donde = estado == null ? '' : 'WHERE estado = :estado';
    final parametros = {'estado': estado?.valor};
    final total = (await _bd.consultar('SELECT COUNT(*) AS n FROM vehiculo $donde', parametros)).single.entero('n');
    final filas = await _bd.consultar(
      'SELECT $_columnas FROM vehiculo $donde ORDER BY codigo LIMIT :limite OFFSET :desde',
      {...parametros, 'limite': pagina.tamano, 'desde': pagina.desplazamiento},
    );
    return Pagina(elementos: filas.map(_vehiculo).toList(), total: total, pagina: pagina.pagina, tamano: pagina.tamano);
  }

  @override
  Future<List<Vehiculo>> todos() async =>
      (await _bd.consultar('SELECT $_columnas FROM vehiculo ORDER BY id')).map(_vehiculo).toList();

  @override
  Future<Vehiculo?> buscar(int id) async {
    final filas = await _bd.consultar('SELECT $_columnas FROM vehiculo WHERE id = :id', {'id': id});
    return filas.isEmpty ? null : _vehiculo(filas.single);
  }

  @override
  Future<bool> existePlaca(String placa, {int? excepto}) async => (await _bd.consultar(
        'SELECT 1 FROM vehiculo WHERE placa = :placa AND id <> :excepto',
        {'placa': placa, 'excepto': excepto ?? 0},
      ))
          .isNotEmpty;

  @override
  Future<bool> existeCodigo(String codigo, {int? excepto}) async => (await _bd.consultar(
        'SELECT 1 FROM vehiculo WHERE codigo = :codigo AND id <> :excepto',
        {'codigo': codigo, 'excepto': excepto ?? 0},
      ))
          .isNotEmpty;

  @override
  Future<int> crear(Vehiculo v) async => (await _bd.ejecutar(
        'INSERT INTO vehiculo (codigo, placa, capacidad, categoria, estado) '
        'VALUES (:codigo, :placa, :capacidad, :categoria, :estado)',
        _parametros(v),
      ))
          .idInsertado;

  @override
  Future<void> actualizar(Vehiculo v) => _bd.ejecutar(
        'UPDATE vehiculo SET codigo = :codigo, placa = :placa, capacidad = :capacidad, '
        'categoria = :categoria, estado = :estado WHERE id = :id',
        {..._parametros(v), 'id': v.id},
      );

  static Map<String, Object?> _parametros(Vehiculo v) => {
        'codigo': v.codigo,
        'placa': v.placa,
        'capacidad': v.capacidad,
        'categoria': v.categoria.valor,
        'estado': v.estado.valor,
      };
}
