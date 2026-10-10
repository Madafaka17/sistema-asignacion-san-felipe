import 'package:flutter/foundation.dart';

/// Versión del cliente; viaja en `X-Version-Cliente` y debe coincidir en
/// MAYOR.MENOR con la versión del contrato del servidor.
const versionCliente = '1.0.0';

/// URL base de la API.
///
/// * Web: el cliente lo sirve nginx en el mismo origen que la API (proxy
///   inverso de `/api`), así que basta una ruta relativa y la cookie del
///   token de actualización es del mismo sitio.
/// * Escritorio: el servidor local, salvo que se indique otra con
///   `--dart-define=API_URL=http://servidor:8080/api`.
Uri urlApiPorDefecto() {
  const definida = String.fromEnvironment('API_URL');
  if (definida.isNotEmpty) return Uri.parse(definida);
  return kIsWeb ? Uri.base.resolve('/api') : Uri.parse('http://localhost:8080/api');
}
