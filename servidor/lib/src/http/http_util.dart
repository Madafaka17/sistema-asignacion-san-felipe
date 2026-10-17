import 'dart:convert';

import 'package:dominio/dominio.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../seguridad/tokens.dart';

const _tipoJson = {'content-type': 'application/json; charset=utf-8'};

Response respuestaJson(Object? cuerpo, {int estado = 200, Map<String, Object>? cabeceras}) => Response(
      estado,
      body: jsonEncode(cuerpo),
      headers: {..._tipoJson, ...?cabeceras},
    );

Response creado(Object? cuerpo, {Map<String, Object>? cabeceras}) =>
    respuestaJson(cuerpo, estado: 201, cabeceras: cabeceras);

Response respuestaError(ExcepcionApi error) =>
    Response(error.estadoHttp, body: jsonEncode(error.toJson()), headers: _tipoJson);

/// Lee el cuerpo JSON; si no es JSON válido responde 400.
Future<Object?> leerJson(Request solicitud) async {
  final texto = await solicitud.readAsString();
  if (texto.trim().isEmpty) {
    throw ExcepcionApi(CodigoError.solicitudInvalida, 'La solicitud no tiene cuerpo');
  }
  try {
    return jsonDecode(texto);
  } on FormatException {
    throw ExcepcionApi(CodigoError.solicitudInvalida, 'El cuerpo no es JSON válido');
  }
}

/// Parámetro numérico de la ruta, por ejemplo `/api/vehiculos/<id>`.
int parametroEntero(Request solicitud, String nombre) {
  final valor = int.tryParse(solicitud.params[nombre] ?? '');
  if (valor == null) throw ExcepcionApi(CodigoError.solicitudInvalida, 'Parámetro $nombre inválido');
  return valor;
}

/// Fecha `AAAA-MM-DD` de la consulta (`?fecha=`).
DateTime? fechaConsulta(Request solicitud, String nombre, {bool obligatoria = false}) {
  final texto = solicitud.url.queryParameters[nombre];
  if (texto == null || texto.isEmpty) {
    if (obligatoria) {
      throw ExcepcionApi(CodigoError.solicitudInvalida, 'Falta el parámetro $nombre', campos: {nombre: 'Campo obligatorio'});
    }
    return null;
  }
  return intentarTextoAFecha(texto) ??
      (throw ExcepcionApi(CodigoError.solicitudInvalida, 'Fecha inválida', campos: {nombre: 'Fecha inválida (AAAA-MM-DD)'}));
}

ParametrosPagina paginaConsulta(Request solicitud) => ParametrosPagina.desdeConsulta(solicitud.url.queryParameters);

const claveUsuario = 'usuario_autenticado';

UsuarioAutenticado usuarioDe(Request solicitud) =>
    solicitud.context[claveUsuario] as UsuarioAutenticado? ??
    (throw ExcepcionApi(CodigoError.noAutenticado, 'Inicie sesión'));

/// Verifica que el rol del usuario pueda leer o modificar el [modulo]
/// (matriz `Permisos` compartida con el cliente).
UsuarioAutenticado autorizar(Request solicitud, Modulo modulo, {bool escritura = false}) {
  final usuario = usuarioDe(solicitud);
  final permitido =
      escritura ? Permisos.puedeEscribir(usuario.rol, modulo) : Permisos.puedeLeer(usuario.rol, modulo);
  if (!permitido) {
    throw ExcepcionApi(CodigoError.prohibido, 'Su rol no tiene acceso a ${modulo.etiqueta}');
  }
  return usuario;
}

String? cookie(Request solicitud, String nombre) {
  final cabecera = solicitud.headers['cookie'];
  if (cabecera == null) return null;
  for (final parte in cabecera.split(';')) {
    final i = parte.indexOf('=');
    if (i > 0 && parte.substring(0, i).trim() == nombre) return parte.substring(i + 1).trim();
  }
  return null;
}
