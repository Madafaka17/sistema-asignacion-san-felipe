import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

import 'apoyo/entorno.dart';

/// Pruebas de contrato de la API (RNF-03): versión, formato de errores,
/// cabeceras de seguridad y CORS.
void main() {
  late Entorno entorno;

  setUpAll(() async {
    entorno = await Entorno.iniciar();
    await entorno.reiniciar();
  });
  tearDownAll(() => entorno.cerrar());

  test('GET /api/version informa la versión del contrato y es compatible con el cliente', () async {
    final r = await entorno.get('/api/version');
    expect(r.estado, 200);
    final info = InfoVersion.fromJson(r.mapa);
    expect(info.versionApi, versionApi);
    expect(versionesCompatibles(info.versionApi, versionApi), isTrue);
  });

  test('un cliente con otra versión MAYOR.MENOR recibe 426; uno compatible pasa', () async {
    final antiguo = await entorno.solicitar('GET', '/api/version', cabeceras: {'x-version-cliente': '0.9.0'});
    expect(antiguo.estado, 426);
    expect(antiguo.error['codigo'], CodigoError.versionIncompatible.valor);
    final compatible = await entorno.solicitar('GET', '/api/version', cabeceras: {'x-version-cliente': '1.0.7'});
    expect(compatible.estado, 200);
  });

  test('todas las respuestas llevan X-Version-Api y las cabeceras de seguridad', () async {
    for (final r in [
      await entorno.get('/api/version'),
      await entorno.get('/api/vehiculos'), // 401
      await entorno.get('/api/no-existe', como: 'jdespacho'), // 404
    ]) {
      expect(r.cabeceras['x-version-api'], versionApi);
      expect(r.cabeceras['x-content-type-options'], 'nosniff');
      expect(r.cabeceras['x-frame-options'], 'DENY');
      expect(r.cabeceras['cache-control'], 'no-store');
    }
  });

  test('los errores tienen la forma {error: {codigo, mensaje, campos}}', () async {
    final r = await entorno.post('/api/vehiculos', {'codigo': 'V-01'}, como: 'jdespacho');
    expect(r.estado, 400);
    expect(r.error['codigo'], CodigoError.solicitudInvalida.valor);
    expect(r.camposError.keys, containsAll(['placa', 'capacidad', 'categoria', 'estado']));
  });

  test('un cuerpo que no es JSON responde 400', () async {
    final r = await entorno.solicitar(
      'POST',
      '/api/vehiculos',
      cabeceras: {'authorization': 'Bearer ${await entorno.token('jdespacho')}', 'content-type': 'application/json'},
    );
    expect(r.estado, 400);
  });

  test('CORS: solo el origen configurado recibe permiso, con credenciales', () async {
    final permitido = await entorno.solicitar('OPTIONS', '/api/servicios', cabeceras: {
      'origin': 'http://localhost:3000',
      'access-control-request-method': 'POST',
    });
    expect(permitido.estado, 204);
    expect(permitido.cabeceras['access-control-allow-origin'], 'http://localhost:3000');
    expect(permitido.cabeceras['access-control-allow-credentials'], 'true');

    final ajeno = await entorno.solicitar('OPTIONS', '/api/servicios', cabeceras: {
      'origin': 'https://sitio-ajeno.example',
      'access-control-request-method': 'POST',
    });
    expect(ajeno.estado, 403);
    expect(ajeno.cabeceras['access-control-allow-origin'], isNull);
  });

  test('GET /api/salud comprueba la conexión con MySQL', () async {
    final r = await entorno.get('/api/salud');
    expect(r.estado, 200);
    expect(r.mapa, {'estado': 'ok', 'baseDatos': 'ok'});
  });
}
