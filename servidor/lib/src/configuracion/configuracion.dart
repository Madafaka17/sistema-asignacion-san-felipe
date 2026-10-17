import 'dart:io';

/// Configuración del servidor leída de variables de entorno (ver
/// `.env.example`). Los secretos nunca se escriben en el código.
class Configuracion {
  const Configuracion({
    required this.puerto,
    required this.dbHost,
    required this.dbPuerto,
    required this.dbNombre,
    required this.dbUsuario,
    required this.dbContrasena,
    required this.dbTls,
    required this.jwtSecreto,
    required this.minutosToken,
    required this.diasRefresco,
    required this.cookieSegura,
    required this.origenesPermitidos,
    required this.archivoParametros,
    required this.desfaseHorarioMin,
  });

  final int puerto;
  final String dbHost;
  final int dbPuerto;
  final String dbNombre;
  final String dbUsuario;
  final String dbContrasena;

  /// MySQL 8.4 exige TLS para el primer inicio de sesión con
  /// `caching_sha2_password` por TCP.
  final bool dbTls;

  /// Clave HS256 de los tokens de acceso; al menos 32 caracteres.
  final String jwtSecreto;
  final int minutosToken;
  final int diasRefresco;

  /// Atributo `Secure` de la cookie del token de actualización. Debe ser
  /// `true` con HTTPS o en `localhost`; con HTTP en la red local el
  /// navegador descartaría la cookie.
  final bool cookieSegura;

  /// Orígenes del cliente que admite CORS en desarrollo, por ejemplo
  /// `http://localhost:3000`.
  final List<String> origenesPermitidos;
  final String archivoParametros;

  /// Desfase de la hora local respecto de UTC (Perú: −300 min, sin horario
  /// de verano).
  final int desfaseHorarioMin;

  static const variablesObligatorias = ['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD', 'JWT_SECRETO'];

  factory Configuracion.desdeEntorno([Map<String, String>? entorno]) {
    final e = entorno ?? Platform.environment;
    final faltantes = [for (final v in variablesObligatorias) if ((e[v] ?? '').isEmpty) v];
    if (faltantes.isNotEmpty) {
      throw StateError('Faltan variables de entorno: ${faltantes.join(', ')}. '
          'Copie .env.example como .env y complete los valores.');
    }
    final secreto = e['JWT_SECRETO']!;
    if (secreto.length < 32) {
      throw StateError('JWT_SECRETO debe tener al menos 32 caracteres.');
    }
    int entero(String nombre, int porDefecto) {
      final texto = e[nombre];
      if (texto == null || texto.isEmpty) return porDefecto;
      return int.tryParse(texto) ?? (throw StateError('$nombre debe ser un número entero: "$texto"'));
    }

    bool booleano(String nombre, bool porDefecto) {
      final texto = e[nombre]?.toLowerCase();
      if (texto == null || texto.isEmpty) return porDefecto;
      return const ['1', 'true', 'si', 'sí'].contains(texto);
    }

    return Configuracion(
      puerto: entero('PUERTO', 8080),
      dbHost: e['DB_HOST']!,
      dbPuerto: entero('DB_PORT', 3306),
      dbNombre: e['DB_NAME']!,
      dbUsuario: e['DB_USER']!,
      dbContrasena: e['DB_PASSWORD']!,
      dbTls: booleano('DB_TLS', true),
      jwtSecreto: secreto,
      minutosToken: entero('JWT_MINUTOS', 15),
      diasRefresco: entero('REFRESH_DIAS', 7),
      cookieSegura: booleano('COOKIE_SEGURA', true),
      origenesPermitidos: [
        for (final o in (e['CORS_ORIGENES'] ?? 'http://localhost:3000').split(','))
          if (o.trim().isNotEmpty) o.trim(),
      ],
      archivoParametros: e['PARAMETROS_ARCHIVO'] ?? 'config/parametros.yaml',
      desfaseHorarioMin: entero('DESFASE_HORARIO_MIN', -300),
    );
  }
}
