import 'package:http/http.dart' as http;

http.Client crearClienteHttp() => http.Client();

/// En escritorio el cliente guarda la cookie del token de actualización en
/// memoria y la envía él mismo (ver `ApiCliente`).
const gestionaCookiesManualmente = true;
