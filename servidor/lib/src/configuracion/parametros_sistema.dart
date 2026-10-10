import 'dart:convert';
import 'dart:io';

import 'package:dominio/dominio.dart';
import 'package:yaml/yaml.dart';

/// Parámetros de `config/parametros.yaml` (RNF-07): el método, sus
/// parámetros y los pesos de `J` se cambian en ese archivo, sin tocar el
/// código.
class ParametrosSistema {
  const ParametrosSistema({
    this.metodo = AlgoritmoGenetico.identificador,
    this.modelo = const ParametrosModelo(),
    this.algoritmoGenetico = const ParametrosAG(),
    this.intentosMaximos = 5,
    this.minutosBloqueo = 15,
    this.iteracionesPbkdf2 = 100000,
    this.minutosDisponiblesVehiculo = 600,
  });

  final String metodo;
  final ParametrosModelo modelo;
  final ParametrosAG algoritmoGenetico;

  /// Bloqueo de la cuenta tras este número de intentos fallidos (HU-01).
  final int intentosMaximos;
  final int minutosBloqueo;
  final int iteracionesPbkdf2;

  /// Tiempo disponible de cada vehículo por día para el indicador PUV
  /// (ecuación 22); la tesis usa un turno de 600 min.
  final int minutosDisponiblesVehiculo;


  factory ParametrosSistema.desdeArchivo(String ruta) =>
      ParametrosSistema.desdeYaml(File(ruta).readAsStringSync());

  factory ParametrosSistema.desdeYaml(String texto) {
    final mapa = _aDart(loadYaml(texto));
    if (mapa is! Map<String, Object?>) {
      throw const FormatException('El archivo de parámetros debe ser un mapa YAML');
    }
    final optimizacion = _mapa(mapa['optimizacion']);
    final seguridad = _mapa(mapa['seguridad']);
    final indicadores = _mapa(mapa['indicadores']);
    final parametros = ParametrosSistema(
      metodo: optimizacion['metodo'] as String? ?? AlgoritmoGenetico.identificador,
      modelo: ParametrosModelo.desdeMapa(_mapa(mapa['modelo'])),
      algoritmoGenetico: ParametrosAG.desdeMapa(_mapa(mapa['algoritmo_genetico'])),
      intentosMaximos: seguridad['intentos_maximos'] as int? ?? 5,
      minutosBloqueo: seguridad['minutos_bloqueo'] as int? ?? 15,
      iteracionesPbkdf2: seguridad['iteraciones_pbkdf2'] as int? ?? 100000,
      minutosDisponiblesVehiculo: indicadores['minutos_disponibles_vehiculo'] as int? ?? 600,
    );
    final errores = [
      if (!FabricaEstrategias.metodosDisponibles.contains(parametros.metodo))
        'optimizacion.metodo debe ser uno de ${FabricaEstrategias.metodosDisponibles}',
      ...parametros.modelo.validar(),
      ...parametros.algoritmoGenetico.validar(),
    ];
    if (errores.isNotEmpty) {
      throw FormatException('Parámetros inválidos:\n- ${errores.join('\n- ')}');
    }
    return parametros;
  }

  /// Parámetros efectivos (los del archivo más los valores por defecto), en
  /// el mismo formato que `config/parametros.yaml`. Se guardan con cada
  /// programación para poder repetir la ejecución.
  Map<String, Object?> toJson() => {
        'optimizacion': {'metodo': metodo},
        'modelo': modelo.toJson(),
        'algoritmo_genetico': algoritmoGenetico.toJson(),
        'seguridad': {
          'intentos_maximos': intentosMaximos,
          'minutos_bloqueo': minutosBloqueo,
          'iteraciones_pbkdf2': iteracionesPbkdf2,
        },
        'indicadores': {'minutos_disponibles_vehiculo': minutosDisponiblesVehiculo},
      };

  String aJson() => jsonEncode(toJson());

  static Object? _aDart(Object? valor) => switch (valor) {
        YamlMap() => {for (final e in valor.entries) e.key.toString(): _aDart(e.value)},
        YamlList() => [for (final v in valor) _aDart(v)],
        _ => valor,
      };

  static Map<String, Object?> _mapa(Object? valor) =>
      valor is Map<String, Object?> ? valor : const {};
}
