import 'dart:convert';
import 'dart:io';

import 'package:dominio/dominio.dart';
import 'package:servidor/servidor.dart';
import 'package:shelf/shelf.dart';

/// Entorno de las pruebas de aceptación: la aplicación completa (rutas,
/// controladores, servicios y repositorios) sobre una base MySQL real de
/// pruebas, con un reloj fijo.
///
/// La base se indica con `PRUEBAS_DB_HOST`, `PRUEBAS_DB_PORT`,
/// `PRUEBAS_DB_NAME`, `PRUEBAS_DB_USER` y `PRUEBAS_DB_PASSWORD`. Como cada
/// prueba borra y recrea las tablas, el nombre de la base debe terminar en
/// `_pruebas`.
class Entorno {
  Entorno._(this.bd, this.reloj, this.aplicacion);

  final BaseDatos bd;
  final RelojFijo reloj;
  final Handler aplicacion;

  /// «Hoy» en las pruebas: la víspera del turno del 12/11/2026 que usan los
  /// escenarios de la Tabla 33 de la tesis.
  static final hoy = DateTime.utc(2026, 11, 11, 10);
  static const turno = '2026-11-12';

  static const usuarios = {
    'admin': ('Admin2026', Rol.administrador),
    'operaciones': ('Opera2026', Rol.operaciones),
    'jdespacho': ('Despacho2026', Rol.despacho),
  };

  /// Las pruebas usan menos iteraciones de PBKDF2 para ser rápidas; el
  /// formato del resumen guarda las iteraciones, así que el código es el
  /// mismo que en producción.
  static const parametros = ParametrosSistema(iteracionesPbkdf2: 1000);

  static Future<Entorno> iniciar() async {
    final e = Platform.environment;
    final nombre = e['PRUEBAS_DB_NAME'] ?? 'sanfelipe_pruebas';
    if (!nombre.endsWith('_pruebas')) {
      throw StateError('PRUEBAS_DB_NAME debe terminar en "_pruebas": las pruebas borran sus tablas.');
    }
    final contrasena = e['PRUEBAS_DB_PASSWORD'] ?? e['DB_PASSWORD'];
    if (contrasena == null || contrasena.isEmpty) {
      throw StateError('Defina PRUEBAS_DB_PASSWORD (ver README, sección Pruebas).');
    }
    final bd = BaseDatos.conectar(
      host: e['PRUEBAS_DB_HOST'] ?? '127.0.0.1',
      puerto: int.parse(e['PRUEBAS_DB_PORT'] ?? '3306'),
      baseDatos: nombre,
      usuario: e['PRUEBAS_DB_USER'] ?? 'sanfelipe',
      contrasena: contrasena,
      tls: (e['PRUEBAS_DB_TLS'] ?? 'true') != 'false',
      maximoConexiones: 4,
    );
    final reloj = RelojFijo(hoy);
    final configuracion = Configuracion.desdeEntorno({
      'DB_HOST': 'no-usado',
      'DB_NAME': nombre,
      'DB_USER': 'no-usado',
      'DB_PASSWORD': 'no-usado',
      'JWT_SECRETO': 'clave-de-pruebas-de-al-menos-32-caracteres',
      'COOKIE_SEGURA': 'true',
      'CORS_ORIGENES': 'http://localhost:3000',
    });
    final aplicacion = crearAplicacion(bd: bd, configuracion: configuracion, parametros: parametros, reloj: reloj);
    return Entorno._(bd, reloj, aplicacion);
  }

  /// Borra y recrea el esquema (`basedatos/esquema.sql`) y registra los
  /// tres usuarios de prueba.
  Future<void> reiniciar() async {
    reloj.momento = hoy;
    final script = File('../basedatos/esquema.sql').readAsStringSync();
    for (final sentencia in sentenciasSql(script)) {
      await bd.ejecutar(sentencia);
    }
    final contrasenas = Contrasenas(iteraciones: parametros.iteracionesPbkdf2);
    for (final MapEntry(key: nombre, value: (clave, rol)) in usuarios.entries) {
      await bd.ejecutar(
        'INSERT INTO usuario (nombre_usuario, nombre_completo, hash_contrasena, rol) '
        'VALUES (:n, :c, :h, :r)',
        {'n': nombre, 'c': 'Usuario $nombre', 'h': contrasenas.resumir(clave), 'r': rol.valor},
      );
    }
    _tokens.clear();
  }

  Future<void> cerrar() => bd.cerrar();

  final _tokens = <String, String>{};

  /// Token de acceso del usuario (se obtiene una vez por prueba).
  Future<String> token(String usuario) async {
    final guardado = _tokens[usuario];
    if (guardado != null) return guardado;
    final r = await ingresar(usuario, usuarios[usuario]!.$1);
    if (r.estado != 200) throw StateError('No se pudo ingresar como $usuario: ${r.texto}');
    return _tokens[usuario] = r.mapa['tokenAcceso'] as String;
  }

  Future<Respuesta> ingresar(String usuario, String contrasena) =>
      solicitar('POST', '/api/auth/ingresar', cuerpo: {'nombreUsuario': usuario, 'contrasena': contrasena});

  /// Envía una solicitud HTTP a la aplicación en memoria (sin red): pasa por
  /// todo el pipeline de middleware, igual que una solicitud real.
  Future<Respuesta> solicitar(
    String metodo,
    String ruta, {
    Object? cuerpo,
    String? como,
    Map<String, String> cabeceras = const {},
  }) async {
    final respuesta = await aplicacion(Request(
      metodo,
      Uri.parse('http://localhost:8080$ruta'),
      body: cuerpo == null ? null : jsonEncode(cuerpo),
      headers: {
        if (cuerpo != null) 'content-type': 'application/json',
        if (como != null) 'authorization': 'Bearer ${await token(como)}',
        ...cabeceras,
      },
    ));
    return Respuesta(respuesta.statusCode, respuesta.headers, await respuesta.readAsString());
  }

  Future<Respuesta> get(String ruta, {String? como}) => solicitar('GET', ruta, como: como);

  Future<Respuesta> post(String ruta, Object? cuerpo, {String? como}) =>
      solicitar('POST', ruta, cuerpo: cuerpo, como: como);

  Future<Respuesta> put(String ruta, Object? cuerpo, {String? como}) =>
      solicitar('PUT', ruta, cuerpo: cuerpo, como: como);

  /// Lectura directa de MySQL para comprobar lo que quedó registrado.
  Future<List<Fila>> consultar(String sql, [Map<String, Object?> parametros = const {}]) =>
      bd.consultar(sql, parametros);
}

class Respuesta {
  Respuesta(this.estado, this.cabeceras, this.texto);

  final int estado;
  final Map<String, String> cabeceras;
  final String texto;

  Object? get json => jsonDecode(texto);

  Map<String, Object?> get mapa => json as Map<String, Object?>;

  List<Object?> get lista => json as List<Object?>;

  Map<String, Object?> get error => mapa['error'] as Map<String, Object?>;

  String get mensajeError => error['mensaje'] as String;

  Map<String, Object?> get camposError => (error['campos'] as Map<String, Object?>?) ?? const {};

  @override
  String toString() => '$estado $texto';
}

/// Separa un script SQL en sentencias (sin comentarios de línea).
List<String> sentenciasSql(String script) {
  final sinComentarios = [
    for (final linea in const LineSplitter().convert(script))
      if (!linea.trimLeft().startsWith('--')) linea,
  ].join('\n');
  return [
    for (final s in sinComentarios.split(RegExp(r';\s*(\n|$)')))
      if (s.trim().isNotEmpty) s.trim(),
  ];
}
