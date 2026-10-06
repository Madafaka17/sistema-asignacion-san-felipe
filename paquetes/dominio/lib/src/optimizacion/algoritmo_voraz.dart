import 'estrategia.dart';
import 'evaluador.dart';
import 'instancia.dart';

/// Algoritmo voraz de primer ajuste (sección 3.1.5, ecuación 12).
///
/// Ordena los servicios por su hora de inicio más temprana (en empate, por
/// mayor prioridad) y asigna a cada uno la primera alternativa, en orden de
/// hora de salida, que no forme un par de `Γ` con lo ya asignado y mantenga
/// al conductor dentro de su límite. Es determinista y casi inmediato: sirve
/// como línea base y como respaldo ante una reprogramación urgente.
class AlgoritmoVoraz implements EstrategiaOptimizacion {
  const AlgoritmoVoraz();

  static const identificador = 'voraz';

  @override
  String get id => identificador;

  @override
  ResultadoOptimizacion resolver(InstanciaTurno instancia) {
    final reloj = Stopwatch()..start();
    final servicios = instancia.admisibles;
    final n = servicios.length;
    final cromosoma = List.filled(n, 0);
    final asignado = List.filled(n, false);
    final cargas = <int, int>{};

    final orden = List.generate(n, (i) => i)
      ..sort((a, b) {
        final ta = servicios[a].alternativas.first.inicio;
        final tb = servicios[b].alternativas.first.inicio;
        if (ta != tb) return ta.compareTo(tb);
        final pa = servicios[a].prioridad;
        final pb = servicios[b].prioridad;
        return pa != pb ? pb.compareTo(pa) : a.compareTo(b);
      });

    for (final i in orden) {
      final alternativas = servicios[i].alternativas;
      // a*(s) = argmín {t_{s,a} : a ∈ A_s, g(a, X_k) = 1}. Como A_s está
      // ordenado por hora de salida, es la primera que cumple g.
      var elegida = -1;
      var menosChoques = -1;
      var choquesMinimos = 1 << 30;
      for (var k = 0; k < alternativas.length; k++) {
        final choques = _choques(instancia, servicios, cromosoma, asignado, cargas, i, alternativas[k]);
        if (choques == 0) {
          elegida = k;
          break;
        }
        if (choques < choquesMinimos) {
          choquesMinimos = choques;
          menosChoques = k;
        }
      }
      // Si ninguna cumple g = 1 se elige la de menor número de choques; el
      // servicio se reporta como incidencia al decodificar.
      cromosoma[i] = elegida >= 0 ? elegida : menosChoques;
      asignado[i] = true;
      final a = alternativas[cromosoma[i]];
      cargas[a.conductorId] = (cargas[a.conductorId] ?? 0) + a.duracion;
    }

    return ResultadoOptimizacion(
      metodo: id,
      cromosoma: cromosoma,
      evaluacion: Evaluador(instancia).evaluar(cromosoma),
      generaciones: 0,
      historial: const [],
      tiempo: reloj.elapsed,
    );
  }

  /// Número de incumplimientos que causaría la alternativa [a] frente a la
  /// programación parcial `X_k`: pares de `Γ` más el exceso del conductor.
  int _choques(
    InstanciaTurno instancia,
    List<ServicioTurno> servicios,
    List<int> cromosoma,
    List<bool> asignado,
    Map<int, int> cargas,
    int i,
    Alternativa a,
  ) {
    var choques = 0;
    for (var j = 0; j < servicios.length; j++) {
      if (j == i || !asignado[j]) continue;
      if (enConflicto(a, servicios[j].alternativas[cromosoma[j]], instancia.holguraMinima)) choques++;
    }
    final conductor = instancia.conductores[a.conductorId];
    if (conductor != null && conductor.acumulado + (cargas[a.conductorId] ?? 0) + a.duracion > conductor.limite) {
      choques++;
    }
    return choques;
  }
}
