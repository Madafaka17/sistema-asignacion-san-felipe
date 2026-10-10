import 'package:dominio/dominio.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../seguridad/tokens.dart';
import 'http_util.dart';

final _registro = Logger('http');

/// Manejo centralizado de errores: cada excepción se convierte en una
/// respuesta JSON con el código HTTP del contrato.
Middleware manejarErrores() => (interno) => (solicitud) async {
      try {
        return await interno(solicitud);
      } on ExcepcionApi catch (e) {
        return respuestaError(e);
      } catch (e, pila) {
        _registro.severe('Error no controlado en ${solicitud.method} ${solicitud.requestedUri.path}', e, pila);
        return respuestaError(ExcepcionApi(CodigoError.interno, 'Error interno del servidor'));
      }
    };

/// CORS: solo admite los orígenes configurados y permite credenciales para
/// que el navegador envíe la cookie del token de actualización.
Middleware cors(List<String> origenesPermitidos) => (interno) => (solicitud) async {
      final origen = solicitud.headers['origin'];
      final permitido = origen != null && origenesPermitidos.contains(origen);
      final cabeceras = permitido
          ? {
              'access-control-allow-origin': origen,
              'access-control-allow-credentials': 'true',
              'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
              'access-control-allow-headers': 'authorization, content-type, x-version-cliente',
              'access-control-expose-headers': 'x-version-api, content-disposition',
              'access-control-max-age': '600',
              'vary': 'Origin',
            }
          : const <String, String>{};
      if (solicitud.method == 'OPTIONS') {
        return Response(permitido ? 204 : 403, headers: cabeceras);
      }
      final respuesta = await interno(solicitud);
      return respuesta.change(headers: cabeceras);
    };

/// Cabeceras de seguridad y versión del contrato en todas las respuestas.
Middleware cabecerasComunes() => (interno) => (solicitud) async {
      final respuesta = await interno(solicitud);
      return respuesta.change(headers: {
        'x-version-api': versionApi,
        'x-content-type-options': 'nosniff',
        'x-frame-options': 'DENY',
        'referrer-policy': 'no-referrer',
        'cache-control': 'no-store',
      });
    };

/// Compatibilidad cliente–servidor: si el cliente declara su versión en
/// `X-Version-Cliente` y no coincide en MAYOR.MENOR con [versionApi], se
/// responde 426 para que el cliente pida actualizarse en lugar de enviar
/// datos con otra forma.
Middleware verificarVersionCliente() => (interno) => (solicitud) {
      final version = solicitud.headers['x-version-cliente'];
      if (version != null && !versionesCompatibles(version, versionApi)) {
        return respuestaError(ExcepcionApi(
          CodigoError.versionIncompatible,
          'El cliente $version no es compatible con la API $versionApi; actualice la aplicación',
        ));
      }
      return interno(solicitud);
    };

/// Autenticación: verifica el JWT de `Authorization: Bearer` y deja el
/// usuario en el contexto. Las rutas públicas no lo exigen.
Middleware autenticar(Tokens tokens, {required Set<String> rutasPublicas}) => (interno) => (solicitud) {
      final ruta = '/${solicitud.url.path}';
      if (rutasPublicas.contains(ruta) || solicitud.method == 'OPTIONS') return interno(solicitud);
      final cabecera = solicitud.headers['authorization'] ?? '';
      final token = cabecera.startsWith('Bearer ') ? cabecera.substring(7) : null;
      final usuario = token == null ? null : tokens.verificarAcceso(token);
      if (usuario == null) {
        return respuestaError(ExcepcionApi(CodigoError.noAutenticado, 'Sesión no válida o expirada'));
      }
      return interno(solicitud.change(context: {claveUsuario: usuario}));
    };

/// Registro de cada solicitud con su duración.
Middleware registrarSolicitudes() => (interno) => (solicitud) async {
      final cronometro = Stopwatch()..start();
      final respuesta = await interno(solicitud);
      _registro.info('${solicitud.method} /${solicitud.url} → ${respuesta.statusCode} '
          '(${cronometro.elapsedMilliseconds} ms)');
      return respuesta;
    };
