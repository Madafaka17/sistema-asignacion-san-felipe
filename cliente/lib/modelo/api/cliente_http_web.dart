import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// El navegador guarda la cookie `HttpOnly` y la envía con
/// `withCredentials`; JavaScript (y por tanto Dart) nunca puede leerla.
http.Client crearClienteHttp() => BrowserClient()..withCredentials = true;

const gestionaCookiesManualmente = false;
