import 'dart:convert';

import 'package:mysql_client_plus/mysql_client_plus.dart';

/// Acceso a MySQL mediante un pool de conexiones.
///
/// Todas las consultas usan parámetros con nombre (`:nombre`); el conector
/// escapa cada valor, de modo que ningún dato del usuario se concatena en el
/// SQL.
class BaseDatos implements Ejecutor {
  BaseDatos._(this._pool);

  factory BaseDatos.conectar({
    required String host,
    required int puerto,
    required String baseDatos,
    required String usuario,
    required String contrasena,
    bool tls = true,
    int maximoConexiones = 10,
  }) =>
      BaseDatos._(MySQLConnectionPool(
        host: host,
        port: puerto,
        userName: usuario,
        password: contrasena,
        databaseName: baseDatos,
        maxConnections: maximoConexiones,
        secure: tls,
        timeoutMs: 10000,
      ));

  final MySQLConnectionPool _pool;

  @override
  Future<List<Fila>> consultar(String sql, [Map<String, Object?> parametros = const {}]) async =>
      _filas(await _pool.execute(sql, _convertir(parametros)));

  @override
  Future<ResultadoEscritura> ejecutar(String sql, [Map<String, Object?> parametros = const {}]) async {
    final r = await _pool.execute(sql, _convertir(parametros));
    return ResultadoEscritura(r.lastInsertID.toInt(), r.affectedRows.toInt());
  }

  /// Ejecuta [accion] en una transacción: confirma si termina bien y
  /// revierte si lanza una excepción (propiedades ACID).
  Future<T> transaccion<T>(Future<T> Function(Ejecutor tx) accion) =>
      _pool.transactional((conexion) => accion(_EjecutorConexion(conexion)));

  Future<void> cerrar() => _pool.close();
}

/// Operaciones comunes al pool y a una transacción.
abstract interface class Ejecutor {
  Future<List<Fila>> consultar(String sql, [Map<String, Object?> parametros]);

  Future<ResultadoEscritura> ejecutar(String sql, [Map<String, Object?> parametros]);
}

class _EjecutorConexion implements Ejecutor {
  _EjecutorConexion(this._conexion);

  final MySQLConnection _conexion;

  @override
  Future<List<Fila>> consultar(String sql, [Map<String, Object?> parametros = const {}]) async =>
      _filas(await _conexion.execute(sql, _convertir(parametros)));

  @override
  Future<ResultadoEscritura> ejecutar(String sql, [Map<String, Object?> parametros = const {}]) async {
    final r = await _conexion.execute(sql, _convertir(parametros));
    return ResultadoEscritura(r.lastInsertID.toInt(), r.affectedRows.toInt());
  }
}

class ResultadoEscritura {
  const ResultadoEscritura(this.idInsertado, this.filasAfectadas);

  final int idInsertado;
  final int filasAfectadas;
}

/// Fila de un resultado con lectores tipados.
class Fila {
  Fila(this._valores);

  final Map<String, Object?> _valores;

  String? textoNulo(String columna) => _valores[columna]?.toString();

  String texto(String columna) =>
      textoNulo(columna) ?? (throw StateError('La columna $columna es NULL'));

  int entero(String columna) => int.parse(texto(columna));

  int? enteroNulo(String columna) {
    final v = textoNulo(columna);
    return v == null ? null : int.parse(v);
  }

  double decimal(String columna) => double.parse(texto(columna));

  bool booleano(String columna) => const ['1', 'true'].contains(texto(columna));

  /// Columna `DATE` → `DateTime` UTC a las 00:00.
  DateTime fecha(String columna) {
    final partes = texto(columna).split('-');
    return DateTime.utc(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2].substring(0, 2)));
  }

  /// Columna `DATETIME` (hora local) → `DateTime` UTC con la misma hora.
  DateTime fechaHora(String columna) => DateTime.parse('${texto(columna).replaceFirst(' ', 'T')}Z');

  DateTime? fechaHoraNula(String columna) => _valores[columna] == null ? null : fechaHora(columna);

  /// Columna `JSON`: el conector puede entregarla como texto o ya decodificada.
  Object? json(String columna) {
    final v = _valores[columna];
    return v is String ? jsonDecode(v) : v;
  }
}

List<Fila> _filas(IResultSet resultado) => [
      for (final fila in resultado.rows) Fila(Map<String, Object?>.of(fila.assoc())),
    ];

/// Convierte los valores al formato que espera MySQL. Las fechas se pasan
/// como texto `AAAA-MM-DD HH:MM:SS` porque el conector no las formatea.
Map<String, Object?> _convertir(Map<String, Object?> parametros) => {
      for (final e in parametros.entries)
        e.key: switch (e.value) {
          DateTime v => formatoFechaHora(v),
          bool v => v ? 1 : 0,
          final v => v,
        },
    };

String formatoFechaHora(DateTime v) {
  String dos(int x) => x.toString().padLeft(2, '0');
  return '${v.year.toString().padLeft(4, '0')}-${dos(v.month)}-${dos(v.day)} '
      '${dos(v.hour)}:${dos(v.minute)}:${dos(v.second)}';
}

String formatoFecha(DateTime v) =>
    '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
