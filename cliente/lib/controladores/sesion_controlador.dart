import 'package:dominio/dominio.dart';

import '../modelo/api/api_cliente.dart';
import 'controlador_base.dart';

enum EstadoSesion { iniciando, incompatible, sinSesion, autenticado }

/// HU-01: ingreso, cierre y expiración de la sesión; decide qué módulos
/// muestra la navegación según el rol (matriz `Permisos` compartida con el
/// servidor).
class SesionControlador extends ControladorBase {
  SesionControlador(this._api) {
    _api.alExpirarSesion = _expirada;
  }

  final ApiCliente _api;

  EstadoSesion _estado = EstadoSesion.iniciando;
  Usuario? _usuario;
  String? _aviso;
  InfoVersion? _version;

  EstadoSesion get estado => _estado;
  Usuario? get usuario => _usuario;
  InfoVersion? get version => _version;

  /// Aviso no bloqueante, por ejemplo «La sesión expiró».
  String? get aviso => _aviso;

  List<Modulo> get modulos => _usuario == null ? const [] : Permisos.modulosNavegacion(_usuario!.rol);

  bool puedeEscribir(Modulo modulo) => _usuario != null && Permisos.puedeEscribir(_usuario!.rol, modulo);

  /// Comprueba la versión del servidor y, si hay cookie de actualización,
  /// reanuda la sesión sin pedir la contraseña.
  Future<void> iniciar() async {
    await ejecutar(() async {
      try {
        _version = await _api.version();
      } on ExcepcionApi catch (e) {
        if (e.codigo == CodigoError.versionIncompatible) {
          _estado = EstadoSesion.incompatible;
        }
        rethrow;
      }
      final sesion = await _api.reanudar();
      _usuario = sesion?.usuario;
      _estado = sesion == null ? EstadoSesion.sinSesion : EstadoSesion.autenticado;
    });
    if (_estado == EstadoSesion.iniciando) _estado = EstadoSesion.sinSesion;
    notificar();
  }

  Future<bool> ingresar(String nombreUsuario, String contrasena) async {
    _aviso = null;
    final sesion = await ejecutar(() => _api.ingresar(nombreUsuario.trim(), contrasena));
    if (sesion == null) return false;
    _usuario = sesion.usuario;
    _estado = EstadoSesion.autenticado;
    notificar();
    return true;
  }

  Future<void> salir() async {
    await ejecutar(_api.salir);
    _usuario = null;
    _estado = EstadoSesion.sinSesion;
    notificar();
  }

  void _expirada() {
    if (_estado != EstadoSesion.autenticado) return;
    _usuario = null;
    _estado = EstadoSesion.sinSesion;
    _aviso = 'La sesión expiró; ingrese nuevamente';
    notificar();
  }
}
