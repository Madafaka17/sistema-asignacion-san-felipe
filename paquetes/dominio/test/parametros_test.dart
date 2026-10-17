import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

/// Parámetros del modelo (Tabla 11) y del algoritmo genético (Tabla 23) que
/// se leen de `config/parametros.yaml` (RNF-07).
void main() {
  group('ParametrosModelo', () {
    test('los valores por defecto cumplen la Tabla 11', () {
      const p = ParametrosModelo();
      expect(p.validar(), isEmpty);
      expect(p.holguraMinima, 10);
      expect(p.penalizacion, 1e6);
      expect(p.pesos.suma, closeTo(1, 1e-12));
    });

    test('se lee de un mapa y vuelve al mismo mapa', () {
      final mapa = {
        'holgura_minima_min': 15,
        'tolerancia_salida_min': 30,
        'penalizacion_m': 1000000,
        'pesos': {'retraso': 0.4, 'reprogramacion': 0.2, 'tiempo_muerto': 0.2, 'desequilibrio': 0.2},
        'referencias': {'retraso_min': 30, 'tiempo_muerto_por_vehiculo_min': 45, 'desequilibrio_min': 20},
        'habilitacion_licencias': {
          'A-IIb': ['M1', 'M2'],
          'A-IIIa': ['M1', 'M2', 'M3'],
        },
      };
      final p = ParametrosModelo.desdeMapa(mapa);
      expect(p.holguraMinima, 15);
      expect(p.toleranciaSalidaMin, 30);
      expect(p.pesos.retraso, 0.4);
      expect(p.referenciaTiempoMuertoPorVehiculoMin, 45);
      expect(p.habilita(CategoriaLicencia.aIIb, CategoriaVehiculo.m2), isTrue);
      expect(p.habilita(CategoriaLicencia.aIIb, CategoriaVehiculo.m3), isFalse);
      expect(p.habilita(CategoriaLicencia.aIIa, CategoriaVehiculo.m1), isFalse, reason: 'no figura en el mapa');
      expect(p.validar(), isEmpty);
      expect(ParametrosModelo.desdeMapa(p.toJson()).toJson(), p.toJson());
    });

    test('un mapa vacío usa los valores por defecto y la matriz de licencias por defecto', () {
      final p = ParametrosModelo.desdeMapa(const {});
      expect(p.toJson(), const ParametrosModelo().toJson());
      expect(p.habilita(CategoriaLicencia.aIIIa, CategoriaVehiculo.m3), isTrue);
    });

    test('valida pesos, referencias, holgura y penalización', () {
      final errores = ParametrosModelo.desdeMapa({
        'holgura_minima_min': -1,
        'tolerancia_salida_min': -5,
        'penalizacion_m': 0,
        'pesos': {'retraso': 1.5, 'reprogramacion': 0.25, 'tiempo_muerto': 0.25, 'desequilibrio': 0.25},
        'referencias': {'retraso_min': 0},
      }).validar();
      expect(errores, containsAll([
        'holgura_minima_min debe ser ≥ 0',
        'tolerancia_salida_min debe ser ≥ 0',
        'penalizacion_m debe ser > 0',
        'Cada peso w_j debe estar en [0, 1]',
        'La suma de los pesos w_j debe ser 1',
        'Las referencias b_j deben ser > 0',
      ]));
    });
  });

  group('ParametrosAG', () {
    test('los valores por defecto son los de la Tabla 23', () {
      const p = ParametrosAG();
      expect(p.validar(), isEmpty);
      expect([p.tamanoPoblacion, p.generacionesMaximas, p.tamanoTorneo, p.generacionesSinMejora], [50, 100, 3, 20]);
      expect(p.numeroElites, 5, reason: 'redondeo(0,10 · 50)');
      expect(p.limiteTiempo, const Duration(seconds: 300));
    });

    test('ida y vuelta por mapa y cambio de semilla', () {
      final p = ParametrosAG.desdeMapa(const {
        'tamano_poblacion': 100,
        'generaciones_maximas': 200,
        'probabilidad_cruce': 0.9,
        'probabilidad_mutacion': 0.2,
        'tamano_torneo': 4,
        'proporcion_elite': 0.05,
        'generaciones_sin_mejora': 30,
        'limite_tiempo_s': 120,
        'pasadas_reparacion': 3,
        'semilla': 7,
      });
      expect(ParametrosAG.desdeMapa(p.toJson()).toJson(), p.toJson());
      final otra = p.conSemilla(11);
      expect(otra.semilla, 11);
      expect(otra.toJson()..remove('semilla'), p.toJson()..remove('semilla'));
    });

    test('rechaza configuraciones imposibles', () {
      final errores = ParametrosAG.desdeMapa(const {
        'tamano_poblacion': 1,
        'generaciones_maximas': -1,
        'probabilidad_cruce': 2,
        'probabilidad_mutacion': -0.1,
        'tamano_torneo': 5,
        'proporcion_elite': 1,
        'generaciones_sin_mejora': 0,
        'limite_tiempo_s': 0,
        'pasadas_reparacion': 0,
      }).validar();
      expect(errores, hasLength(9));
    });
  });

  test('FabricaEstrategias crea el AG con sus parámetros y el voraz como línea base', () {
    expect(FabricaEstrategias.crear('algoritmo_genetico'), isA<AlgoritmoGenetico>());
    expect(FabricaEstrategias.crear('voraz'), isA<AlgoritmoVoraz>());
  });
}
