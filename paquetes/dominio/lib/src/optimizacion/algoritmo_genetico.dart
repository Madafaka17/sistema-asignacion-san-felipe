import 'dart:math' as math;

import '../modelos/programacion.dart';
import 'estrategia.dart';
import 'evaluador.dart';
import 'instancia.dart';
import 'parametros.dart';
import 'reparacion.dart';

/// Algoritmo genético de la sección 3.4 de la tesis.
///
/// Cada bloque del método [resolver] corresponde a una línea del pseudocódigo
/// de la Tabla 22; los comentarios `[3.4.x]` y `[ec. n]` remiten a la
/// sección o ecuación de la tesis.
class AlgoritmoGenetico implements EstrategiaOptimizacion {
  const AlgoritmoGenetico([this.parametros = const ParametrosAG()]);

  static const identificador = 'algoritmo_genetico';

  final ParametrosAG parametros;

  @override
  String get id => identificador;

  @override
  ResultadoOptimizacion resolver(InstanciaTurno instancia) {
    final p = parametros;
    final reloj = Stopwatch()..start();
    final aleatorio = math.Random(p.semilla);
    final evaluador = Evaluador(instancia);
    final reparador = Reparador(instancia, pasadasMaximas: p.pasadasReparacion);

    // S' ← {s ∈ S : A_s ≠ ∅}. Los servicios con A_s = ∅ se reportan como
    // incidencia al decodificar; aquí solo forman parte de S.
    final servicios = instancia.admisibles;
    final n = servicios.length;
    if (n == 0) {
      return ResultadoOptimizacion(
        metodo: id,
        cromosoma: const [],
        evaluacion: evaluador.evaluar(const []),
        generaciones: 0,
        historial: const [],
        tiempo: reloj.elapsed,
        semilla: p.semilla,
      );
    }

    // P(0) ← P cromosomas con α_s aleatorio en {0, …, |A_s| − 1}.
    // PARA cada α en P(0): α ← Reparar(α)                      [3.4.2, 3.4.9]
    var poblacion = [
      for (var k = 0; k < p.tamanoPoblacion; k++)
        reparador.reparar([
          for (var i = 0; i < n; i++) aleatorio.nextInt(servicios[i].alternativas.length),
        ]),
    ];

    // Evaluar F(α) para cada α en P(0)                          [ec. 7]
    var aptitudes = [for (final alfa in poblacion) evaluador.evaluar(alfa).aptitud];

    // α_mejor ← mejor de P(0);  g ← 0;  sin_mejora ← 0
    var indiceMejor = _indiceMejor(aptitudes);
    var mejor = List.of(poblacion[indiceMejor]);
    var aptitudMejor = aptitudes[indiceMejor];
    var g = 0;
    var sinMejora = 0;
    final historial = [PuntoConvergencia(0, aptitudMejor, _promedio(aptitudes))];

    // MIENTRAS g < G_máx Y sin_mejora < g_conv Y tiempo < t_lím HACER
    while (g < p.generacionesMaximas &&
        sinMejora < p.generacionesSinMejora &&
        reloj.elapsed < p.limiteTiempo) {
      // Q ← los redondeo(ε·P) mejores de P(g)                   [3.4.7]
      final orden = List.generate(poblacion.length, (i) => i)
        ..sort((a, b) {
          final porAptitud = aptitudes[b].compareTo(aptitudes[a]);
          return porAptitud != 0 ? porAptitud : a.compareTo(b);
        });
      final siguiente = [for (final i in orden.take(p.numeroElites)) List.of(poblacion[i])];
      final aptitudesSiguiente = [for (final i in orden.take(p.numeroElites)) aptitudes[i]];

      // MIENTRAS |Q| < P HACER
      final hijos = <List<int>>[];
      while (siguiente.length + hijos.length < p.tamanoPoblacion) {
        // padre1 ← Torneo(P(g), k);  padre2 ← Torneo(P(g), k)   [3.4.4]
        final padre1 = poblacion[_torneo(aptitudes, aleatorio)];
        final padre2 = poblacion[_torneo(aptitudes, aleatorio)];

        // SI aleatorio() < p_c ENTONCES hijo ← CruceUniforme(padre1, padre2)
        // SINO hijo ← copia(padre1)                              [3.4.5]
        var hijo = aleatorio.nextDouble() < p.probabilidadCruce
            ? _cruceUniforme(padre1, padre2, aleatorio)
            : List.of(padre1);

        // SI aleatorio() < p_m ENTONCES hijo ← Mutar(hijo)       [3.4.6]
        if (aleatorio.nextDouble() < p.probabilidadMutacion) {
          hijo = _mutar(hijo, servicios, aleatorio);
        }

        // hijo ← Reparar(hijo);  Q ← Q ∪ {hijo}                 [3.4.9]
        hijos.add(reparador.reparar(hijo));
      }

      // Evaluar F de los nuevos cromosomas de Q
      siguiente.addAll(hijos);
      aptitudesSiguiente.addAll([for (final hijo in hijos) evaluador.evaluar(hijo).aptitud]);

      // P(g+1) ← Q;  g ← g + 1
      poblacion = siguiente;
      aptitudes = aptitudesSiguiente;
      g++;

      // SI F(mejor de P(g)) > F(α_mejor) ENTONCES α_mejor ← mejor de P(g);
      // sin_mejora ← 0  SINO sin_mejora ← sin_mejora + 1
      indiceMejor = _indiceMejor(aptitudes);
      if (aptitudes[indiceMejor] > aptitudMejor) {
        mejor = List.of(poblacion[indiceMejor]);
        aptitudMejor = aptitudes[indiceMejor];
        sinMejora = 0;
      } else {
        sinMejora++;
      }
      historial.add(PuntoConvergencia(g, aptitudMejor, _promedio(aptitudes)));
    }

    // X_mejor ← Decodificar(α_mejor)                            [ec. 15]
    // DEVOLVER X_mejor, F(X_mejor), Φ(X_mejor) y tiempo de ejecución
    return ResultadoOptimizacion(
      metodo: id,
      cromosoma: mejor,
      evaluacion: evaluador.evaluar(mejor),
      generaciones: g,
      historial: historial,
      tiempo: reloj.elapsed,
      semilla: p.semilla,
    );
  }

  /// Selección por torneo [3.4.4]: se toman al azar `k` cromosomas (con
  /// reemplazo) y gana el de mayor aptitud.
  int _torneo(List<double> aptitudes, math.Random aleatorio) {
    var ganador = aleatorio.nextInt(aptitudes.length);
    for (var r = 1; r < parametros.tamanoTorneo; r++) {
      final retador = aleatorio.nextInt(aptitudes.length);
      if (aptitudes[retador] > aptitudes[ganador]) ganador = retador;
    }
    return ganador;
  }

  /// Cruce uniforme [3.4.5]: cada gen se hereda de uno u otro progenitor con
  /// igual probabilidad, en la misma posición.
  List<int> _cruceUniforme(List<int> padre1, List<int> padre2, math.Random aleatorio) => [
        for (var i = 0; i < padre1.length; i++) aleatorio.nextBool() ? padre1[i] : padre2[i],
      ];

  /// Mutación [3.4.6]: se elige al azar un servicio con más de una alternativa
  /// y se reemplaza su gen por otra alternativa admisible elegida al azar.
  /// Cambia a la vez vehículo, conductor y salida; la ruta no cambia.
  List<int> _mutar(List<int> cromosoma, List<ServicioTurno> servicios, math.Random aleatorio) {
    final mutables = [
      for (var i = 0; i < cromosoma.length; i++)
        if (servicios[i].alternativas.length > 1) i,
    ];
    if (mutables.isEmpty) return cromosoma;
    final i = mutables[aleatorio.nextInt(mutables.length)];
    var nuevo = aleatorio.nextInt(servicios[i].alternativas.length - 1);
    if (nuevo >= cromosoma[i]) nuevo++;
    return List.of(cromosoma)..[i] = nuevo;
  }

  static int _indiceMejor(List<double> aptitudes) {
    var mejor = 0;
    for (var i = 1; i < aptitudes.length; i++) {
      if (aptitudes[i] > aptitudes[mejor]) mejor = i;
    }
    return mejor;
  }

  static double _promedio(List<double> valores) =>
      valores.isEmpty ? 0 : valores.fold(0.0, (s, v) => s + v) / valores.length;
}
