import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

abstract interface class RepositorioConductores {
  Future<Pagina<Conductor>> listar(ParametrosPagina pagina);

  Future<List<Conductor>> todos();

  Future<Conductor?> buscar(int id);

  Future<bool> existeCodigo(String codigo, {int? excepto});

  Future<bool> existeDni(String dni, {int? excepto});

  Future<int> crear(Conductor conductor);

  Future<void> actualizar(Conductor conductor);

  Future<void> cambiarDisponibilidad(int id, bool disponible);
}

class RepositorioConductoresMysql implements RepositorioConductores {
  const RepositorioConductoresMysql(this._bd);

  final BaseDatos _bd;

  static const _columnas = 'id, codigo, dni, nombres, apellidos, categoria_licencia, vencimiento_licencia, '
      'turno_inicio, turno_fin, minutos_acumulados, limite_minutos, disponible';

  static Conductor _conductor(Fila f) => Conductor(
        id: f.entero('id'),
        codigo: f.texto('codigo'),
        dni: f.texto('dni'),
        nombres: f.texto('nombres'),
        apellidos: f.texto('apellidos'),
        categoriaLicencia: CategoriaLicencia.desdeValor(f.texto('categoria_licencia')),
        vencimientoLicencia: f.fecha('vencimiento_licencia'),
        turnoInicio: f.entero('turno_inicio'),
        turnoFin: f.entero('turno_fin'),
        minutosAcumulados: f.entero('minutos_acumulados'),
        limiteMinutos: f.entero('limite_minutos'),
        disponible: f.booleano('disponible'),
      );

  @override
  Future<Pagina<Conductor>> listar(ParametrosPagina pagina) async {
    final total = (await _bd.consultar('SELECT COUNT(*) AS n FROM conductor')).single.entero('n');
    final filas = await _bd.consultar(
      'SELECT $_columnas FROM conductor ORDER BY codigo LIMIT :limite OFFSET :desde',
      {'limite': pagina.tamano, 'desde': pagina.desplazamiento},
    );
    return Pagina(elementos: filas.map(_conductor).toList(), total: total, pagina: pagina.pagina, tamano: pagina.tamano);
  }

  @override
  Future<List<Conductor>> todos() async =>
      (await _bd.consultar('SELECT $_columnas FROM conductor ORDER BY id')).map(_conductor).toList();

  @override
  Future<Conductor?> buscar(int id) async {
    final filas = await _bd.consultar('SELECT $_columnas FROM conductor WHERE id = :id', {'id': id});
    return filas.isEmpty ? null : _conductor(filas.single);
  }

  @override
  Future<bool> existeCodigo(String codigo, {int? excepto}) async => (await _bd.consultar(
        'SELECT 1 FROM conductor WHERE codigo = :codigo AND id <> :excepto',
        {'codigo': codigo, 'excepto': excepto ?? 0},
      ))
          .isNotEmpty;

  @override
  Future<bool> existeDni(String dni, {int? excepto}) async => (await _bd.consultar(
        'SELECT 1 FROM conductor WHERE dni = :dni AND id <> :excepto',
        {'dni': dni, 'excepto': excepto ?? 0},
      ))
          .isNotEmpty;

  @override
  Future<int> crear(Conductor c) async => (await _bd.ejecutar(
        'INSERT INTO conductor (codigo, dni, nombres, apellidos, categoria_licencia, vencimiento_licencia, '
        'turno_inicio, turno_fin, minutos_acumulados, limite_minutos, disponible) '
        'VALUES (:codigo, :dni, :nombres, :apellidos, :licencia, :vencimiento, :inicio, :fin, '
        ':acumulados, :limite, :disponible)',
        _parametros(c),
      ))
          .idInsertado;

  @override
  Future<void> actualizar(Conductor c) => _bd.ejecutar(
        'UPDATE conductor SET codigo = :codigo, dni = :dni, nombres = :nombres, apellidos = :apellidos, '
        'categoria_licencia = :licencia, vencimiento_licencia = :vencimiento, turno_inicio = :inicio, '
        'turno_fin = :fin, minutos_acumulados = :acumulados, limite_minutos = :limite, '
        'disponible = :disponible WHERE id = :id',
        {..._parametros(c), 'id': c.id},
      );

  @override
  Future<void> cambiarDisponibilidad(int id, bool disponible) => _bd.ejecutar(
        'UPDATE conductor SET disponible = :disponible WHERE id = :id',
        {'id': id, 'disponible': disponible},
      );

  static Map<String, Object?> _parametros(Conductor c) => {
        'codigo': c.codigo,
        'dni': c.dni,
        'nombres': c.nombres,
        'apellidos': c.apellidos,
        'licencia': c.categoriaLicencia.valor,
        'vencimiento': formatoFecha(c.vencimientoLicencia),
        'inicio': c.turnoInicio,
        'fin': c.turnoFin,
        'acumulados': c.minutosAcumulados,
        'limite': c.limiteMinutos,
        'disponible': c.disponible,
      };
}
