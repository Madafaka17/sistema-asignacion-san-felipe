import 'dart:math' as math;

import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

import 'apoyo.dart';

void main() {
  group('Predicado γ de la ecuación (4)', () {
    const tmin = 10;
    Alternativa a(int v, int c, int inicio, int d) =>
        Alternativa(vehiculoId: v, conductorId: c, salida: inicio, duracion: d);

    test('mismo vehículo con superposición: conflicto', () {
      expect(enConflicto(a(1, 1, 0, 60), a(1, 2, 30, 60), tmin), isTrue);
    });

    test('mismo conductor separado por menos de t_mín: conflicto', () {
      expect(enConflicto(a(1, 1, 0, 60), a(2, 1, 65, 60), tmin), isTrue);
    });

    test('separado exactamente por t_mín: sin conflicto', () {
      expect(enConflicto(a(1, 1, 0, 60), a(1, 1, 70, 60), tmin), isFalse);
    });

    test('recursos distintos: sin conflicto aunque se superpongan', () {
      expect(enConflicto(a(1, 1, 0, 60), a(2, 2, 0, 60), tmin), isFalse);
    });

    test('es simétrico', () {
      final x = a(1, 3, 100, 50);
      final y = a(1, 4, 140, 30);
      expect(enConflicto(x, y, tmin), enConflicto(y, x, tmin));
    });
  });

  group('Función de aptitud F(X) sobre la Tabla 21', () {
    final instancia = instanciaTabla21();
    final evaluador = Evaluador(instancia);

    test('el cromosoma α = (0, 0, 1, 0) de la tesis es factible: Φ = 0', () {
      final evaluacion = evaluador.evaluar([0, 0, 1, 0]);
      expect(evaluacion.phi, 0);
      // V01 y C03 se reutilizan en S01 y S04: S04 inicia 15 min después del
      // fin de S01 (08:00 → 08:15), más que t_mín = 10 min.
      expect(evaluacion.componentes.tiempoMuertoMin, 15);
      expect(evaluacion.aptitud, greaterThan(-instancia.penalizacion));
    });

    test('α = (1, 0, 0, 0) cruza V02 (S01–S03) y C01 (S01–S02): Cv = 1, Cc = 1', () {
      final evaluacion = evaluador.evaluar([1, 0, 0, 0]);
      expect(evaluacion.componentes.conflictosVehiculo, 1);
      expect(evaluacion.componentes.conflictosConductor, 1);
      expect(evaluacion.phi, 2);
      expect(evaluacion.aptitud, lessThan(-2 * instancia.penalizacion + 1));
    });

    test('toda solución factible tiene mayor aptitud que cualquier infactible', () {
      expect(evaluador.evaluar([0, 0, 1, 0]).aptitud, greaterThan(evaluador.evaluar([1, 0, 0, 0]).aptitud));
    });

    test('E(X) y N_exc cuentan el exceso sobre H_cmáx', () {
      // C03 maneja S01 y S04 (240 min); con límite 200 excede 40 min.
      final evaluacion = Evaluador(instanciaTabla21(limites: {3: 200})).evaluar([0, 0, 1, 0]);
      expect(evaluacion.componentes.conductoresExcedidos, 1);
      expect(evaluacion.componentes.excesoMin, 40);
      expect(evaluacion.phi, 1);
    });

    test('D(X) es la desviación estándar poblacional de las cargas', () {
      final evaluacion = evaluador.evaluar([0, 0, 1, 0]);
      // Cargas: C03 = 240, C01 = 90, C05 = 60.
      const media = (240 + 90 + 60) / 3;
      final esperado = math.sqrt(
          (math.pow(240 - media, 2) + math.pow(90 - media, 2) + math.pow(60 - media, 2)) / 3);
      expect(evaluacion.componentes.desviacionCarga, closeTo(esperado, 1e-9));
      expect(evaluacion.cargas, {3: 240, 1: 90, 5: 60});
    });
  });

  group('Ret(X) y R(X) frente a la programación comprometida', () {
    InstanciaTurno conComprometida(Alternativa comprometida) {
      final base = instanciaTabla21();
      final servicios = [
        for (final s in base.servicios)
          s.servicioId == 2
              ? ServicioTurno(
                  servicioId: s.servicioId,
                  codigo: s.codigo,
                  codigoRuta: s.codigoRuta,
                  prioridad: s.prioridad,
                  capacidadRequerida: s.capacidadRequerida,
                  alternativas: s.alternativas,
                  comprometida: comprometida,
                )
              : s,
      ];
      return InstanciaTurno(
        fecha: base.fecha,
        servicios: servicios,
        conductores: base.conductores,
        codigosVehiculo: base.codigosVehiculo,
        holguraMinima: base.holguraMinima,
        pesos: base.pesos,
        referencias: base.referencias,
      );
    }

    test('mantener la alternativa comprometida no suma retraso ni reprogramación', () {
      final instancia = conComprometida(instanciaTabla21().admisibles[1].alternativas[0]);
      final c = Evaluador(instancia).evaluar([0, 0, 1, 0]).componentes;
      expect(c.retrasoMin, 0);
      expect(c.reprogramados, 0);
    });

    test('cambiar a una salida posterior suma el retraso y una reprogramación', () {
      final instancia = conComprometida(instanciaTabla21().admisibles[1].alternativas[0]);
      // Alternativa 2 de S02 sale a las 06:45 en lugar de 06:15: 30 min.
      final c = Evaluador(instancia).evaluar([0, 2, 1, 0]).componentes;
      expect(c.retrasoMin, 30);
      expect(c.reprogramados, 1);
    });
  });

  group('Validador independiente', () {
    test('coincide con Φ del evaluador en 300 cromosomas aleatorios', () {
      for (final semilla in [101, 102, 103]) {
        final instancia = GeneradorInstancias.generar(servicios: 14, semilla: semilla);
        final evaluador = Evaluador(instancia);
        final validador = Validador(holguraMinima: instancia.holguraMinima);
        final aleatorio = math.Random(semilla);
        for (var k = 0; k < 100; k++) {
          final cromosoma = [
            for (final s in instancia.admisibles) aleatorio.nextInt(s.alternativas.length),
          ];
          final phiEvaluador = evaluador.evaluar(cromosoma).phi;
          final phiValidador =
              validador.validar(comoValidables(instancia, cromosoma), limitesDe(instancia)).phi;
          expect(phiValidador, phiEvaluador, reason: 'semilla $semilla, cromosoma $cromosoma');
        }
      }
    });
  });
}
