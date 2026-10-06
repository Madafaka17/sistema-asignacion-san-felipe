import '../modelos/conductor.dart';
import '../modelos/vehiculo.dart';
import 'instancia.dart';

/// Parámetros del modelo (Tabla 11) que se leen de `config/parametros.yaml`.
class ParametrosModelo {
  const ParametrosModelo({
    this.holguraMinima = 10,
    this.toleranciaSalidaMin = 60,
    this.penalizacion = 1e6,
    this.pesos = const PesosPerdida(),
    this.referenciaRetrasoMin = 60,
    this.referenciaTiempoMuertoPorVehiculoMin = 60,
    this.referenciaDesequilibrioMin = 60,
    this.habilitacion = habilitacionPorDefecto,
  });

  /// `t_mín`, en minutos.
  final int holguraMinima;

  /// Ventana que define `H_s`: las salidas autorizadas de la ruta entre la
  /// hora solicitada y la hora solicitada más esta tolerancia.
  final int toleranciaSalidaMin;

  /// `M`.
  final double penalizacion;

  /// `w_j`.
  final PesosPerdida pesos;

  /// `b_Ret`.
  final double referenciaRetrasoMin;

  /// `b_Tm = este valor · |V|`.
  final double referenciaTiempoMuertoPorVehiculoMin;

  /// `b_D`.
  final double referenciaDesequilibrioMin;

  /// Categorías vehiculares que habilita cada categoría de licencia; define
  /// `λ(c, v)` junto con la vigencia de la licencia.
  final Map<CategoriaLicencia, Set<CategoriaVehiculo>> habilitacion;

  /// Valores por defecto; deben contrastarse con el Reglamento Nacional de
  /// Licencias de Conducir vigente antes de usarse en producción.
  static const habilitacionPorDefecto = <CategoriaLicencia, Set<CategoriaVehiculo>>{
    CategoriaLicencia.aIIa: {CategoriaVehiculo.m1},
    CategoriaLicencia.aIIb: {CategoriaVehiculo.m1, CategoriaVehiculo.m2},
    CategoriaLicencia.aIIIa: {CategoriaVehiculo.m1, CategoriaVehiculo.m2, CategoriaVehiculo.m3},
    CategoriaLicencia.aIIIb: {CategoriaVehiculo.m1, CategoriaVehiculo.m2},
    CategoriaLicencia.aIIIc: {CategoriaVehiculo.m1, CategoriaVehiculo.m2, CategoriaVehiculo.m3},
  };

  bool habilita(CategoriaLicencia licencia, CategoriaVehiculo vehiculo) =>
      habilitacion[licencia]?.contains(vehiculo) ?? false;

  factory ParametrosModelo.desdeMapa(Map<String, Object?> mapa) {
    final pesos = _mapa(mapa['pesos']);
    final referencias = _mapa(mapa['referencias']);
    final habilitacion = _mapa(mapa['habilitacion_licencias']);
    return ParametrosModelo(
      holguraMinima: _entero(mapa['holgura_minima_min'], 10),
      toleranciaSalidaMin: _entero(mapa['tolerancia_salida_min'], 60),
      penalizacion: _decimal(mapa['penalizacion_m'], 1e6),
      pesos: PesosPerdida(
        retraso: _decimal(pesos['retraso'], 0.25),
        reprogramacion: _decimal(pesos['reprogramacion'], 0.25),
        tiempoMuerto: _decimal(pesos['tiempo_muerto'], 0.25),
        desequilibrio: _decimal(pesos['desequilibrio'], 0.25),
      ),
      referenciaRetrasoMin: _decimal(referencias['retraso_min'], 60),
      referenciaTiempoMuertoPorVehiculoMin:
          _decimal(referencias['tiempo_muerto_por_vehiculo_min'], 60),
      referenciaDesequilibrioMin: _decimal(referencias['desequilibrio_min'], 60),
      habilitacion: habilitacion.isEmpty
          ? habilitacionPorDefecto
          : {
              for (final e in habilitacion.entries)
                CategoriaLicencia.desdeValor(e.key): {
                  for (final v in (e.value as List)) CategoriaVehiculo.desdeValor(v.toString()),
                },
            },
    );
  }

  /// Mismo formato que la sección `modelo` de `config/parametros.yaml`.
  Map<String, Object?> toJson() => {
        'holgura_minima_min': holguraMinima,
        'tolerancia_salida_min': toleranciaSalidaMin,
        'penalizacion_m': penalizacion,
        'pesos': {
          'retraso': pesos.retraso,
          'reprogramacion': pesos.reprogramacion,
          'tiempo_muerto': pesos.tiempoMuerto,
          'desequilibrio': pesos.desequilibrio,
        },
        'referencias': {
          'retraso_min': referenciaRetrasoMin,
          'tiempo_muerto_por_vehiculo_min': referenciaTiempoMuertoPorVehiculoMin,
          'desequilibrio_min': referenciaDesequilibrioMin,
        },
        'habilitacion_licencias': {
          for (final e in habilitacion.entries) e.key.valor: [for (final v in e.value) v.valor],
        },
      };

  /// Valida las restricciones de la Tabla 11 (`w_j ∈ [0, 1]`, `Σ w_j = 1`).
  List<String> validar() => [
        if (holguraMinima < 0) 'holgura_minima_min debe ser ≥ 0',
        if (toleranciaSalidaMin < 0) 'tolerancia_salida_min debe ser ≥ 0',
        if (penalizacion <= 0) 'penalizacion_m debe ser > 0',
        for (final w in [pesos.retraso, pesos.reprogramacion, pesos.tiempoMuerto, pesos.desequilibrio])
          if (w < 0 || w > 1) 'Cada peso w_j debe estar en [0, 1]',
        if ((pesos.suma - 1).abs() > 1e-9) 'La suma de los pesos w_j debe ser 1',
        if (referenciaRetrasoMin <= 0 ||
            referenciaTiempoMuertoPorVehiculoMin <= 0 ||
            referenciaDesequilibrioMin <= 0)
          'Las referencias b_j deben ser > 0',
      ];
}

/// Parámetros iniciales del algoritmo genético (Tabla 23 de la tesis).
class ParametrosAG {
  const ParametrosAG({
    this.tamanoPoblacion = 50,
    this.generacionesMaximas = 100,
    this.probabilidadCruce = 0.80,
    this.probabilidadMutacion = 0.10,
    this.tamanoTorneo = 3,
    this.proporcionElite = 0.10,
    this.generacionesSinMejora = 20,
    this.limiteTiempo = const Duration(seconds: 300),
    this.pasadasReparacion = 5,
    this.semilla = 1,
  });

  /// `P`.
  final int tamanoPoblacion;

  /// `G_máx`.
  final int generacionesMaximas;

  /// `p_c`.
  final double probabilidadCruce;

  /// `p_m`, por descendiente.
  final double probabilidadMutacion;

  /// `k`.
  final int tamanoTorneo;

  /// `ε`.
  final double proporcionElite;

  /// `g_conv`.
  final int generacionesSinMejora;

  /// `t_lím`.
  final Duration limiteTiempo;

  /// `ϱ`: pasadas máximas de la reparación dirigida.
  final int pasadasReparacion;
  final int semilla;

  /// `redondeo(ε·P)`.
  int get numeroElites => (proporcionElite * tamanoPoblacion).round();

  ParametrosAG conSemilla(int semilla) => ParametrosAG(
        tamanoPoblacion: tamanoPoblacion,
        generacionesMaximas: generacionesMaximas,
        probabilidadCruce: probabilidadCruce,
        probabilidadMutacion: probabilidadMutacion,
        tamanoTorneo: tamanoTorneo,
        proporcionElite: proporcionElite,
        generacionesSinMejora: generacionesSinMejora,
        limiteTiempo: limiteTiempo,
        pasadasReparacion: pasadasReparacion,
        semilla: semilla,
      );

  factory ParametrosAG.desdeMapa(Map<String, Object?> mapa) => ParametrosAG(
        tamanoPoblacion: _entero(mapa['tamano_poblacion'], 50),
        generacionesMaximas: _entero(mapa['generaciones_maximas'], 100),
        probabilidadCruce: _decimal(mapa['probabilidad_cruce'], 0.80),
        probabilidadMutacion: _decimal(mapa['probabilidad_mutacion'], 0.10),
        tamanoTorneo: _entero(mapa['tamano_torneo'], 3),
        proporcionElite: _decimal(mapa['proporcion_elite'], 0.10),
        generacionesSinMejora: _entero(mapa['generaciones_sin_mejora'], 20),
        limiteTiempo: Duration(seconds: _entero(mapa['limite_tiempo_s'], 300)),
        pasadasReparacion: _entero(mapa['pasadas_reparacion'], 5),
        semilla: _entero(mapa['semilla'], 1),
      );

  Map<String, Object?> toJson() => {
        'tamano_poblacion': tamanoPoblacion,
        'generaciones_maximas': generacionesMaximas,
        'probabilidad_cruce': probabilidadCruce,
        'probabilidad_mutacion': probabilidadMutacion,
        'tamano_torneo': tamanoTorneo,
        'proporcion_elite': proporcionElite,
        'generaciones_sin_mejora': generacionesSinMejora,
        'limite_tiempo_s': limiteTiempo.inSeconds,
        'pasadas_reparacion': pasadasReparacion,
        'semilla': semilla,
      };

  List<String> validar() => [
        if (tamanoPoblacion < 2) 'tamano_poblacion debe ser ≥ 2',
        if (generacionesMaximas < 0) 'generaciones_maximas debe ser ≥ 0',
        if (probabilidadCruce < 0 || probabilidadCruce > 1) 'probabilidad_cruce debe estar en [0, 1]',
        if (probabilidadMutacion < 0 || probabilidadMutacion > 1)
          'probabilidad_mutacion debe estar en [0, 1]',
        if (tamanoTorneo < 1 || tamanoTorneo > tamanoPoblacion)
          'tamano_torneo debe estar entre 1 y tamano_poblacion',
        if (numeroElites < 0 || numeroElites >= tamanoPoblacion)
          'proporcion_elite debe dejar lugar a descendientes',
        if (generacionesSinMejora < 1) 'generaciones_sin_mejora debe ser ≥ 1',
        if (limiteTiempo <= Duration.zero) 'limite_tiempo_s debe ser > 0',
        if (pasadasReparacion < 1) 'pasadas_reparacion debe ser ≥ 1',
      ];
}

Map<String, Object?> _mapa(Object? valor) =>
    valor is Map ? {for (final e in valor.entries) e.key.toString(): e.value} : const {};

int _entero(Object? valor, int porDefecto) => valor is int ? valor : porDefecto;

double _decimal(Object? valor, double porDefecto) => valor is num ? valor.toDouble() : porDefecto;
