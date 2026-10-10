import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Intercambio HTTP observado por la prueba de ciclo completo.
class Intercambio {
  Intercambio(this.metodo, this.ruta, this.cuerpoEnviado);

  final String metodo;
  final String ruta;
  final Object? cuerpoEnviado;
  int? estado;
  Object? cuerpoRecibido;

  @override
  String toString() => '$metodo $ruta → $estado';
}

/// Envuelve el cliente HTTP real: registra cada solicitud y su respuesta
/// (para verificar el payload y el 201) y puede retener una respuesta para
/// observar la interfaz mientras la solicitud está en curso.
class ClienteGrabador extends http.BaseClient {
  ClienteGrabador(this._interno);

  final http.Client _interno;
  final intercambios = <Intercambio>[];

  /// Si se asigna, la próxima respuesta a `metodo ruta` espera a que se
  /// complete este `Completer`.
  ({String metodo, String ruta, Completer<void> liberar})? retener;

  Iterable<Intercambio> de(String metodo, String ruta) =>
      intercambios.where((i) => i.metodo == metodo && i.ruta == ruta);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest solicitud) async {
    final cuerpo = solicitud is http.Request && solicitud.body.isNotEmpty ? jsonDecode(solicitud.body) : null;
    final intercambio = Intercambio(solicitud.method, solicitud.url.path, cuerpo);
    intercambios.add(intercambio);
    final respuesta = await http.Response.fromStream(await _interno.send(solicitud));
    final r = retener;
    if (r != null && r.metodo == solicitud.method && r.ruta == solicitud.url.path) {
      retener = null;
      await r.liberar.future;
    }
    intercambio
      ..estado = respuesta.statusCode
      ..cuerpoRecibido = respuesta.body.isEmpty || !(respuesta.headers['content-type'] ?? '').contains('json')
          ? respuesta.body
          : jsonDecode(utf8.decode(respuesta.bodyBytes));
    return http.StreamedResponse(
      Stream.value(respuesta.bodyBytes),
      respuesta.statusCode,
      headers: respuesta.headers,
      request: solicitud,
      reasonPhrase: respuesta.reasonPhrase,
    );
  }
}
