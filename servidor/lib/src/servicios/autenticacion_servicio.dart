import 'package:dominio/dominio.dart';

import '../configuracion/parametros_sistema.dart';
import '../infraestructura/base_datos.dart';
import '../infraestructura/reloj.dart';
import '../repositorios/repositorio_bitacora.dart';
import '../repositorios/repositorio_sesiones.dart';
import '../repositorios/repositorio_usuarios.dart';
import '../seguridad/contrasenas.dart';
import '../seguridad/tokens.dart';

/// Sesión emitida: el cuerpo de la respuesta y el token de actualización que
/// viaja en la cookie `HttpOnly`.
class SesionEmitida {
  const SesionEmitida(this.sesion, this.tokenActualizacion, this.duracionActualizacion);

  final SesionIniciada sesion;
  final String tokenActualizacion;
  final Duration duracionActualizacion;
}

/// Inicio de sesión, renovación y cierre (HU-01, RNF-06).
class AutenticacionServicio {
  AutenticacionServicio({
    required this.bd,
    required this.usuarios,
    required this.sesiones,
    required this.bitacora,
    required this.contrasenas,
    required this.tokens,
    required this.reloj,
    required this.parametros,
    required this.duracionActualizacion,
  });

  final Ejecutor bd;
  final RepositorioUsuarios usuarios;
  final RepositorioSesiones sesiones;
  final RepositorioBitacora bitacora;
  final Contrasenas contrasenas;
  final Tokens tokens;
  final Reloj reloj;
  final ParametrosSistema parametros;
  final Duration duracionActualizacion;

  static const mensajeCredenciales = 'Usuario o contraseña incorrectos';
  static const mensajeBloqueo = 'Cuenta bloqueada temporalmente';

  /// Resumen ficticio para que un usuario inexistente tarde lo mismo que uno
  /// existente y no se pueda averiguar qué usuarios existen.
  late final String _resumenFicticio = contrasenas.resumir('contraseña-inexistente');

  Future<SesionEmitida> ingresar(String nombreUsuario, String contrasena) async {
    final registro = await usuarios.buscarPorNombre(nombreUsuario.trim().toLowerCase());
    final ahora = reloj.ahora();
    if (registro == null || !registro.usuario.activo) {
      contrasenas.verificar(contrasena, _resumenFicticio);
      throw ExcepcionApi(CodigoError.noAutenticado, mensajeCredenciales);
    }
    final usuario = registro.usuario;
    final bloqueadoHasta = registro.bloqueadoHasta;
    if (bloqueadoHasta != null && bloqueadoHasta.isAfter(ahora)) {
      throw ExcepcionApi(CodigoError.bloqueado, mensajeBloqueo);
    }

    if (!contrasenas.verificar(contrasena, registro.hashContrasena)) {
      // Un bloqueo vencido reinicia el conteo de intentos.
      final intentos = (bloqueadoHasta == null ? registro.intentosFallidos : 0) + 1;
      if (intentos >= parametros.intentosMaximos) {
        final hasta = ahora.add(Duration(minutes: parametros.minutosBloqueo));
        await usuarios.actualizarIntentos(usuario.id, 0, hasta);
        await bitacora.registrar(
          bd,
          usuarioId: usuario.id,
          accion: 'bloqueo_cuenta',
          entidad: 'usuario',
          entidadId: usuario.id,
          detalle: {'intentos': intentos, 'bloqueadoHasta': hasta.toIso8601String()},
          fechaHora: ahora,
        );
        throw ExcepcionApi(CodigoError.bloqueado, mensajeBloqueo);
      }
      await usuarios.actualizarIntentos(usuario.id, intentos, null);
      throw ExcepcionApi(CodigoError.noAutenticado, mensajeCredenciales);
    }

    await usuarios.actualizarIntentos(usuario.id, 0, null);
    await bitacora.registrar(
      bd,
      usuarioId: usuario.id,
      accion: 'inicio_sesion',
      entidad: 'usuario',
      entidadId: usuario.id,
      fechaHora: ahora,
    );
    return _emitir(usuario, ahora);
  }

  /// Renueva el token de acceso y rota el token de actualización: el
  /// anterior queda revocado.
  Future<SesionEmitida> refrescar(String? tokenActualizacion) async {
    final ahora = reloj.ahora();
    final sesion = tokenActualizacion == null
        ? null
        : await sesiones.buscarVigente(Tokens.resumen(tokenActualizacion), ahora);
    if (sesion == null) throw ExcepcionApi(CodigoError.noAutenticado, 'La sesión expiró; ingrese nuevamente');
    final usuario = await usuarios.buscar(sesion.usuarioId);
    if (usuario == null || !usuario.activo) {
      throw ExcepcionApi(CodigoError.noAutenticado, 'La sesión expiró; ingrese nuevamente');
    }
    await sesiones.revocar(sesion.id);
    return _emitir(usuario, ahora);
  }

  Future<void> salir(String? tokenActualizacion) async {
    if (tokenActualizacion == null) return;
    final sesion = await sesiones.buscarVigente(Tokens.resumen(tokenActualizacion), reloj.ahora());
    if (sesion != null) await sesiones.revocar(sesion.id);
  }

  Future<SesionEmitida> _emitir(Usuario usuario, DateTime ahora) async {
    final acceso = tokens.emitirAcceso(
      UsuarioAutenticado(id: usuario.id, nombreUsuario: usuario.nombreUsuario, rol: usuario.rol),
    );
    final actualizacion = Tokens.nuevoTokenActualizacion();
    await sesiones.crear(usuario.id, Tokens.resumen(actualizacion), ahora.add(duracionActualizacion));
    return SesionEmitida(
      SesionIniciada(
        tokenAcceso: acceso,
        expiraEnSegundos: tokens.duracionAcceso.inSeconds,
        usuario: usuario,
      ),
      actualizacion,
      duracionActualizacion,
    );
  }
}
