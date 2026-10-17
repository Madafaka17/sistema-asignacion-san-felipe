import 'evaluador.dart';
import 'instancia.dart';

/// Mecanismo de reparación dirigida (sección 3.4.9 de la tesis).
///
/// La ecuación (1) ya excluye los recursos no disponibles o no habilitados,
/// por lo que la reparación solo atiende las dos restricciones duras que
/// dependen de la combinación de genes: los conflictos de `Γ` y el límite de
/// conducción. Es determinista: con el mismo cromosoma devuelve siempre el
/// mismo resultado.
class Reparador {
  const Reparador(this.instancia, {this.pasadasMaximas = 5});

  final InstanciaTurno instancia;

  /// `ϱ`.
  final int pasadasMaximas;

  List<int> reparar(List<int> cromosoma) {
    final estado = _Estado(instancia, List.of(cromosoma));
    for (var pasada = 0; pasada < pasadasMaximas; pasada++) {
      var cambios = false;

      // Paso 1. Para cada conflicto se conserva el servicio de mayor
      // prioridad (en empate, el de inicio más temprano) y el otro se
      // reasigna; si no se puede, se intenta reasignar el conservado.
      for (var i = 0; i < estado.n; i++) {
        for (var j = i + 1; j < estado.n; j++) {
          if (!enConflicto(estado.elegida(i), estado.elegida(j), instancia.holguraMinima)) continue;
          final (conservar, mover) = estado.ordenarPorPrioridad(i, j);
          if (estado.reasignar(mover) || estado.reasignar(conservar)) cambios = true;
        }
      }

      // Paso 2. Para cada conductor que supera su límite se reasigna uno de
      // sus servicios con el mismo criterio, empezando por el de menor
      // prioridad (en empate, el de inicio más tardío).
      final conductores = instancia.conductores.keys.toList()..sort();
      for (final conductorId in conductores) {
        while (estado.excede(conductorId)) {
          final candidatos = estado.serviciosDe(conductorId)
            ..sort((a, b) {
              final porPrioridad = estado.prioridad(a).compareTo(estado.prioridad(b));
              if (porPrioridad != 0) return porPrioridad;
              final porInicio = estado.elegida(b).inicio.compareTo(estado.elegida(a).inicio);
              return porInicio != 0 ? porInicio : b.compareTo(a);
            });
          final movido = candidatos.any(estado.reasignar);
          if (!movido) break;
          cambios = true;
        }
      }

      // Se repite hasta que no haya cambios, con un máximo de ϱ pasadas.
      if (!cambios) break;
    }
    // Los conflictos que no pudieron resolverse quedan en el cromosoma,
    // penalizados por M, y se reportan como incidencia al decodificar.
    return estado.cromosoma;
  }
}

class _Estado {
  _Estado(this.instancia, this.cromosoma) {
    for (var i = 0; i < n; i++) {
      final a = elegida(i);
      cargas[a.conductorId] = (cargas[a.conductorId] ?? 0) + a.duracion;
    }
  }

  final InstanciaTurno instancia;
  final List<int> cromosoma;
  final Map<int, int> cargas = {};

  int get n => cromosoma.length;

  Alternativa elegida(int i) => instancia.admisibles[i].alternativas[cromosoma[i]];

  int prioridad(int i) => instancia.admisibles[i].prioridad;

  /// Devuelve `(conservar, mover)`.
  (int, int) ordenarPorPrioridad(int i, int j) {
    final pi = prioridad(i);
    final pj = prioridad(j);
    if (pi != pj) return pi > pj ? (i, j) : (j, i);
    final ti = elegida(i).inicio;
    final tj = elegida(j).inicio;
    if (ti != tj) return ti < tj ? (i, j) : (j, i);
    return (i, j);
  }

  bool excede(int conductorId) {
    final conductor = instancia.conductores[conductorId];
    if (conductor == null) return false;
    return conductor.acumulado + (cargas[conductorId] ?? 0) > conductor.limite;
  }

  List<int> serviciosDe(int conductorId) =>
      [for (var i = 0; i < n; i++) if (elegida(i).conductorId == conductorId) i];

  /// Reasigna el servicio [i] a la primera alternativa admisible, en orden de
  /// hora de salida, que no genere un conflicto con los demás servicios y
  /// mantenga a su conductor dentro del límite.
  bool reasignar(int i) {
    final actual = elegida(i);
    final alternativas = instancia.admisibles[i].alternativas;
    for (var k = 0; k < alternativas.length; k++) {
      if (k == cromosoma[i]) continue;
      final candidata = alternativas[k];
      if (!_dentroDelLimite(candidata, actual)) continue;
      if (_chocaConOtros(i, candidata)) continue;
      cargas[actual.conductorId] = cargas[actual.conductorId]! - actual.duracion;
      cargas[candidata.conductorId] = (cargas[candidata.conductorId] ?? 0) + candidata.duracion;
      cromosoma[i] = k;
      return true;
    }
    return false;
  }

  bool _dentroDelLimite(Alternativa candidata, Alternativa actual) {
    final conductor = instancia.conductores[candidata.conductorId];
    if (conductor == null) return false;
    var carga = cargas[candidata.conductorId] ?? 0;
    if (actual.conductorId == candidata.conductorId) carga -= actual.duracion;
    return conductor.acumulado + carga + candidata.duracion <= conductor.limite;
  }

  bool _chocaConOtros(int i, Alternativa candidata) {
    for (var j = 0; j < n; j++) {
      if (j != i && enConflicto(candidata, elegida(j), instancia.holguraMinima)) return true;
    }
    return false;
  }
}
