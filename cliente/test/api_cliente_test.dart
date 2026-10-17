import 'package:cliente/modelo/api/api_cliente.dart';
import 'package:dominio/dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'apoyo/servidor_simulado.dart';

void main() {
  late ServidorSimulado servidor;
  late ApiCliente api;

  setUp(() {
    servidor = ServidorSimulado()..conSesion(usuarioDespacho);
    api = ApiCliente(base: Uri.parse('http://servidor/api'), cliente: servidor.cliente);
  });

  test('guarda el token de acceso en memoria y lo envía como Bearer', () async {
    await api.ingresar('jdespacho', 'Despacho2026');
    servidor.en('GET', '/api/vehiculos', (_) => ServidorSimulado.json(
          const Pagina<Vehiculo>(elementos: [], total: 0, pagina: 1, tamano: 50).toJson((v) => v.toJson()),
        ));
    await api.get('/vehiculos');
    expect(servidor.de('GET', '/api/vehiculos').single.cabeceras['authorization'], 'Bearer token-de-prueba');
  });

  test('ante un 401 renueva el token con la cookie y repite la solicitud una vez', () async {
    await api.ingresar('jdespacho', 'Despacho2026');
    var llamadas = 0;
    servidor
      ..en('GET', '/api/rutas', (s) {
        llamadas++;
        return s.headers['authorization'] == 'Bearer token-renovado'
            ? ServidorSimulado.json(<Object?>[])
            : ServidorSimulado.json(ExcepcionApi(CodigoError.noAutenticado, 'expirado').toJson(), 401);
      })
      ..en('POST', '/api/auth/refrescar', (s) {
        expect(s.headers['cookie'], 'refresco=abc', reason: 'la cookie recibida al ingresar');
        return ServidorSimulado.json(
          const SesionIniciada(tokenAcceso: 'token-renovado', expiraEnSegundos: 900, usuario: usuarioDespacho).toJson(),
          200,
          {'set-cookie': 'refresco=def; Path=/api/auth; HttpOnly'},
        );
      });
    expect(await api.get('/rutas'), isEmpty);
    expect(llamadas, 2);
    expect(servidor.de('POST', '/api/auth/refrescar'), hasLength(1));
  });

  test('si la renovación falla purga la sesión y avisa', () async {
    await api.ingresar('jdespacho', 'Despacho2026');
    var avisos = 0;
    api.alExpirarSesion = () => avisos++;
    servidor.en('GET', '/api/rutas', (_) => ServidorSimulado.json(ExcepcionApi(CodigoError.noAutenticado, 'expirado').toJson(), 401));
    await expectLater(api.get('/rutas'), throwsA(isA<ExcepcionApi>().having((e) => e.codigo, 'código', CodigoError.noAutenticado)));
    expect(avisos, 1);
    expect(api.tieneSesion, isFalse);
  });

  test('rechaza un servidor con otra versión MAYOR.MENOR del contrato', () async {
    servidor.en('GET', '/api/version', (_) => ServidorSimulado.json(
          const InfoVersion(versionApi: '2.0.0', versionServidor: '2.0.0').toJson(),
          200,
          {'x-version-api': '2.0.0'},
        ));
    await expectLater(api.version(), throwsA(isA<ExcepcionApi>().having((e) => e.codigo, 'código', CodigoError.versionIncompatible)));
  });

  test('convierte la respuesta de error del contrato en ExcepcionApi con sus campos', () async {
    servidor.en('POST', '/api/vehiculos', (_) => ServidorSimulado.json(
          ExcepcionApi(CodigoError.conflicto, 'La placa ya está registrada', campos: {'placa': 'La placa ya está registrada'}).toJson(),
          409,
        ));
    await expectLater(
      api.post('/vehiculos', {'placa': 'ABC-123'}),
      throwsA(isA<ExcepcionApi>()
          .having((e) => e.codigo, 'código', CodigoError.conflicto)
          .having((e) => e.campos['placa'], 'campo', 'La placa ya está registrada')),
    );
  });

  test('un fallo de red se informa como ErrorConexion', () async {
    final caido = ApiCliente(
      base: Uri.parse('http://servidor/api'),
      cliente: _ClienteCaido(),
    );
    await expectLater(caido.get('/version'), throwsA(isA<ErrorConexion>()));
  });
}

class _ClienteCaido extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw http.ClientException('sin red', request.url);
}
