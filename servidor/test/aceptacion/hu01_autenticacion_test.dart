import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

import '../apoyo/entorno.dart';

/// HU-01: registro de usuarios con rol, acceso según el rol y bloqueo por
/// intentos fallidos (Tabla 33 de la tesis; RNF-06).
void main() {
  late Entorno entorno;

  setUpAll(() async => entorno = await Entorno.iniciar());
  setUp(() => entorno.reiniciar());
  tearDownAll(() => entorno.cerrar());

  group('HU-01 Acceso según el rol (feliz)', () {
    test('jdespacho ve solo registro e incidencias; aprobación, reportes y administración quedan ocultos', () async {
      final r = await entorno.ingresar('jdespacho', 'Despacho2026');
      expect(r.estado, 200);
      final sesion = SesionIniciada.fromJson(r.mapa);
      expect(sesion.usuario.rol, Rol.despacho);
      expect(sesion.tokenAcceso, isNotEmpty);

      // El cliente decide qué mostrar con la misma matriz que usa el servidor.
      final modulos = Permisos.modulosNavegacion(sesion.usuario.rol);
      expect(modulos, containsAll([
        Modulo.vehiculos,
        Modulo.conductores,
        Modulo.rutas,
        Modulo.servicios,
        Modulo.incidencias,
      ]));
      expect(modulos, isNot(anyOf(contains(Modulo.programacion), contains(Modulo.reportes), contains(Modulo.usuarios))));

      // Y el servidor lo hace cumplir aunque se llame a la API directamente.
      expect((await entorno.get('/api/programaciones', como: 'jdespacho')).estado, 403);
      expect((await entorno.get('/api/reportes/indicadores?desde=2026-11-01&hasta=2026-11-30', como: 'jdespacho')).estado, 403);
      expect((await entorno.get('/api/usuarios', como: 'jdespacho')).estado, 403);
      expect((await entorno.get('/api/vehiculos', como: 'jdespacho')).estado, 200);
    });

    test('el token de actualización viaja en una cookie HttpOnly, SameSite=Strict y Secure', () async {
      final r = await entorno.ingresar('jdespacho', 'Despacho2026');
      final cookie = r.cabeceras['set-cookie']!;
      expect(cookie, startsWith('refresco='));
      expect(cookie, allOf(contains('HttpOnly'), contains('SameSite=Strict'), contains('Secure'), contains('Path=/api/auth')));
      expect(r.texto, isNot(contains(cookie.split(';').first.substring('refresco='.length))),
          reason: 'el token de actualización no debe ir en el cuerpo');
    });

    test('el token de actualización rota: el anterior deja de servir', () async {
      final r = await entorno.ingresar('jdespacho', 'Despacho2026');
      final cookie = r.cabeceras['set-cookie']!.split(';').first;
      final renovada = await entorno.solicitar('POST', '/api/auth/refrescar', cabeceras: {'cookie': cookie});
      expect(renovada.estado, 200);
      expect(renovada.cabeceras['set-cookie'], isNot(startsWith(cookie)));
      final reutilizada = await entorno.solicitar('POST', '/api/auth/refrescar', cabeceras: {'cookie': cookie});
      expect(reutilizada.estado, 401);
    });

    test('el administrador registra un usuario con su rol', () async {
      final r = await entorno.post(
        '/api/usuarios',
        const SolicitudUsuario(
          nombreUsuario: 'mrojas',
          nombreCompleto: 'Usuario Nuevo',
          rol: Rol.operaciones,
          contrasena: 'Clave2026',
        ).toJson(),
        como: 'admin',
      );
      expect(r.estado, 201);
      expect(r.mapa['rol'], 'operaciones');
      expect(r.texto, isNot(contains('Clave2026')));
      final fila = (await entorno.consultar("SELECT hash_contrasena FROM usuario WHERE nombre_usuario = 'mrojas'")).single;
      expect(fila.texto('hash_contrasena'), startsWith(r'pbkdf2_sha256$'));
      expect((await entorno.ingresar('mrojas', 'Clave2026')).estado, 200);
    });

    test('usuario duplicado (409) y contraseña débil (422)', () async {
      Future<Respuesta> crear(String nombre, String clave) => entorno.post(
            '/api/usuarios',
            SolicitudUsuario(nombreUsuario: nombre, nombreCompleto: 'X', rol: Rol.despacho, contrasena: clave).toJson(),
            como: 'admin',
          );
      expect((await crear('jdespacho', 'Clave2026')).estado, 409);
      final debil = await crear('nuevo', 'corta');
      expect(debil.estado, 422);
      expect(debil.camposError, contains('contrasena'));
    });
  });

  group('HU-01 Bloqueo por intentos fallidos (error)', () {
    test('la quinta contraseña incorrecta bloquea la cuenta 15 minutos y queda en la bitácora', () async {
      for (var i = 1; i <= 4; i++) {
        final r = await entorno.ingresar('jdespacho', 'incorrecta$i');
        expect(r.estado, 401, reason: 'intento $i');
        expect(r.mensajeError, 'Usuario o contraseña incorrectos');
      }
      final quinto = await entorno.ingresar('jdespacho', 'incorrecta5');
      expect(quinto.estado, 423);
      expect(quinto.mensajeError, 'Cuenta bloqueada temporalmente');

      final eventos = await entorno.consultar(
        "SELECT b.accion, u.nombre_usuario FROM bitacora b JOIN usuario u ON u.id = b.usuario_id WHERE b.accion = 'bloqueo_cuenta'",
      );
      expect(eventos, hasLength(1));
      expect(eventos.single.texto('nombre_usuario'), 'jdespacho');

      // Durante el bloqueo ni la contraseña correcta permite ingresar.
      entorno.reloj.avanzar(const Duration(minutes: 14));
      expect((await entorno.ingresar('jdespacho', 'Despacho2026')).estado, 423);

      // Pasados los 15 minutos, sí.
      entorno.reloj.avanzar(const Duration(minutes: 2));
      expect((await entorno.ingresar('jdespacho', 'Despacho2026')).estado, 200);
    });

    test('un usuario inexistente recibe el mismo mensaje que una contraseña incorrecta', () async {
      final r = await entorno.ingresar('noexiste', 'Cualquiera1');
      expect(r.estado, 401);
      expect(r.mensajeError, 'Usuario o contraseña incorrectos');
    });

    test('sin token o con un token alterado la API responde 401', () async {
      expect((await entorno.get('/api/vehiculos')).estado, 401);
      final token = await entorno.token('jdespacho');
      final alterado = '${token.substring(0, token.length - 2)}xx';
      final r = await entorno.solicitar('GET', '/api/vehiculos', cabeceras: {'authorization': 'Bearer $alterado'});
      expect(r.estado, 401);
    });
  });
}
