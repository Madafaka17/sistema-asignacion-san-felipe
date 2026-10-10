import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

import 'apoyo.dart';

void main() {
  group('Reparación dirigida (3.4.9)', () {
    test('elimina los cruces de α = (1, 0, 0, 0) en la Tabla 21', () {
      final instancia = instanciaTabla21();
      final reparado = Reparador(instancia).reparar([1, 0, 0, 0]);
      expect(Evaluador(instancia).evaluar(reparado).phi, 0);
    });

    test('es determinista', () {
      final instancia = GeneradorInstancias.generar(servicios: 28, semilla: 102);
      final cromosoma = [for (final s in instancia.admisibles) s.alternativas.length - 1];
      expect(Reparador(instancia).reparar(cromosoma), Reparador(instancia).reparar(cromosoma));
    });

    test('no empeora Φ en instancias sintéticas', () {
      for (final semilla in [101, 102, 103]) {
        final instancia = GeneradorInstancias.generar(servicios: 28, semilla: semilla);
        final evaluador = Evaluador(instancia);
        final cromosoma = List.filled(instancia.n, 0);
        final antes = evaluador.evaluar(cromosoma).phi;
        final despues = evaluador.evaluar(Reparador(instancia).reparar(cromosoma)).phi;
        expect(despues, lessThanOrEqualTo(antes));
      }
    });

    test('conserva el servicio de mayor prioridad y reasigna el otro', () {
      // S03 (prioridad 3) y S01 (prioridad 2) chocan en V02; se mantiene S03.
      final instancia = instanciaTabla21(prioridadS03: 3);
      final reparado = Reparador(instancia).reparar([1, 1, 0, 0]);
      expect(reparado[2], 0, reason: 'S03 conserva su alternativa');
      expect(Evaluador(instancia).evaluar(reparado).phi, 0);
    });
  });

  group('Algoritmo genético (Tabla 22)', () {
    const parametros = ParametrosAG(semilla: 7);

    test('encuentra una programación factible en la Tabla 21', () {
      final resultado = const AlgoritmoGenetico(parametros).resolver(instanciaTabla21());
      expect(resultado.evaluacion.phi, 0);
      expect(resultado.cromosoma, hasLength(4));
    });

    test('es reproducible: la misma semilla da el mismo resultado', () {
      final instancia = GeneradorInstancias.generar(servicios: 14, semilla: 101);
      final a = const AlgoritmoGenetico(parametros).resolver(instancia);
      final b = const AlgoritmoGenetico(parametros).resolver(instancia);
      expect(a.cromosoma, b.cromosoma);
      expect(a.generaciones, b.generaciones);
      expect([for (final p in a.historial) p.mejor], [for (final p in b.historial) p.mejor]);
    });

    test('el elitismo hace que la mejor aptitud nunca disminuya', () {
      final instancia = GeneradorInstancias.generar(servicios: 28, semilla: 103);
      final historial = const AlgoritmoGenetico(parametros).resolver(instancia).historial;
      for (var g = 1; g < historial.length; g++) {
        expect(historial[g].mejor, greaterThanOrEqualTo(historial[g - 1].mejor));
      }
    });

    test('se detiene por convergencia tras g_conv generaciones sin mejora', () {
      final resultado = const AlgoritmoGenetico(
        ParametrosAG(semilla: 3, generacionesMaximas: 1000, generacionesSinMejora: 5),
      ).resolver(instanciaTabla21());
      expect(resultado.generaciones, lessThan(1000));
      final ultimos = resultado.historial.sublist(resultado.historial.length - 6);
      expect(ultimos.map((p) => p.mejor).toSet(), hasLength(1));
    });

    test('en n = 7 alcanza Φ = 0 y queda a menos de 5 % del óptimo exacto', () {
      for (final semilla in [101, 102, 103]) {
        final instancia = GeneradorInstancias.generar(servicios: 7, semilla: semilla);
        final (_, optimo) = optimoExhaustivo(instancia);
        final ag = const AlgoritmoGenetico(ParametrosAG(semilla: 1, tamanoPoblacion: 100, generacionesMaximas: 200))
            .resolver(instancia);
        expect(ag.evaluacion.phi, 0, reason: 'semilla $semilla');
        final brecha = (optimo - ag.evaluacion.aptitud) / optimo.abs() * 100;
        expect(brecha, lessThan(5), reason: 'semilla $semilla: brecha $brecha %');
      }
    });

    test('una instancia sin servicios admisibles devuelve un cromosoma vacío', () {
      final vacia = InstanciaTurno(
        fecha: DateTime.utc(2026),
        servicios: const [],
        conductores: const {},
        codigosVehiculo: const {},
        holguraMinima: 10,
        pesos: const PesosPerdida(),
        referencias: const ReferenciasPerdida(retraso: 60, reprogramacion: 1, tiempoMuerto: 60, desequilibrio: 60),
      );
      final resultado = const AlgoritmoGenetico().resolver(vacia);
      expect(resultado.cromosoma, isEmpty);
      expect(resultado.evaluacion.phi, 0);
    });
  });

  group('Algoritmo voraz (ecuación 12)', () {
    test('asigna la Tabla 21 sin conflictos', () {
      final resultado = const AlgoritmoVoraz().resolver(instanciaTabla21());
      expect(resultado.evaluacion.phi, 0);
    });

    test('es determinista', () {
      final instancia = GeneradorInstancias.generar(servicios: 28, semilla: 101);
      expect(const AlgoritmoVoraz().resolver(instancia).cromosoma,
          const AlgoritmoVoraz().resolver(instancia).cromosoma);
    });
  });

  group('Fábrica de estrategias', () {
    test('crea las estrategias por su identificador', () {
      expect(FabricaEstrategias.crear('algoritmo_genetico'), isA<AlgoritmoGenetico>());
      expect(FabricaEstrategias.crear('voraz'), isA<AlgoritmoVoraz>());
    });

    test('rechaza un método desconocido', () {
      expect(() => FabricaEstrategias.crear('tabu'), throwsArgumentError);
    });
  });

  group('Decodificador', () {
    test('las asignaciones resultantes cumplen Φ = 0 según el validador', () {
      for (final semilla in [101, 102, 103]) {
        final instancia = GeneradorInstancias.generar(servicios: 56, semilla: semilla);
        // Cromosoma sin reparar, con muchos conflictos.
        final cromosoma = List.filled(instancia.n, 0);
        final resultado = Decodificador(instancia).decodificar(cromosoma);
        final asignadas = [
          for (final r in resultado.where((r) => r.asignado))
            AsignacionValidable(
              servicioId: r.servicio.servicioId,
              vehiculoId: r.alternativa!.vehiculoId,
              conductorId: r.alternativa!.conductorId,
              inicio: r.alternativa!.inicio,
              fin: r.alternativa!.fin,
            ),
        ];
        final validacion = Validador(holguraMinima: instancia.holguraMinima).validar(asignadas, limitesDe(instancia));
        expect(validacion.phi, 0);
        expect(resultado, hasLength(instancia.servicios.length));
        expect(resultado.where((r) => !r.asignado).every((r) => r.motivo != null), isTrue);
      }
    });

    test('reporta como incidencia al servicio de menor prioridad de un cruce', () {
      final instancia = instanciaTabla21(prioridadS03: 1);
      final resultado = Decodificador(instancia).decodificar([1, 1, 0, 0]);
      final s03 = resultado.firstWhere((r) => r.servicio.codigo == 'S03');
      expect(s03.asignado, isFalse);
      expect(s03.motivo, contains('S01'));
    });
  });
}
