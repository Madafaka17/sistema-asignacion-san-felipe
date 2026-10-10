import 'dart:math' as math;

import '../modelos/programacion.dart';
import 'instancia.dart';

/// `γ(a, a')` de la ecuación (4): las alternativas de dos servicios
/// distintos están en conflicto si comparten vehículo o conductor y sus
/// intervalos se superponen o quedan separados por menos de `t_mín`.
///
/// `Γ` no se materializa: con `|A_s|` de cientos de alternativas por servicio
/// el número de pares crecería con `K²`. Se evalúa este predicado solo sobre
/// las alternativas elegidas, que es lo que exige la ecuación (5).
bool enConflicto(Alternativa a, Alternativa b, int holguraMinima) =>
    (a.vehiculoId == b.vehiculoId || a.conductorId == b.conductorId) &&
    a.inicio < b.inicio + b.duracion + holguraMinima &&
    b.inicio < a.inicio + a.duracion + holguraMinima;

/// Resultado de evaluar una programación `X` con la ecuación (7).
class Evaluacion {
  const Evaluacion({
    required this.aptitud,
    required this.componentes,
    required this.cargas,
  });

  /// `F(X) = −[M·Φ(X) + E(X) + J(X)]`.
  final double aptitud;
  final ComponentesAptitud componentes;

  /// `ℓ_c(X)`: minutos asignados a cada conductor con al menos un servicio.
  final Map<int, int> cargas;

  /// `Φ(X)`; la programación es factible si y solo si vale 0.
  int get phi => componentes.phi;
}

/// Evaluador de la función de aptitud común (ecuaciones 7 y 8).
class Evaluador {
  const Evaluador(this.instancia);

  final InstanciaTurno instancia;

  /// Decodifica `α` (ecuación 15): el gen `i` elige la alternativa
  /// `A_s[α_i]` del servicio `s = S'[i]`.
  Map<int, Alternativa> decodificar(List<int> alfa) => {
        for (var i = 0; i < alfa.length; i++)
          instancia.admisibles[i].servicioId: instancia.admisibles[i].alternativas[alfa[i]],
      };

  Evaluacion evaluar(List<int> alfa) => evaluarProgramacion(decodificar(alfa));

  /// Evalúa una programación dada como servicio → alternativa elegida. Los
  /// servicios de `S` que no figuran en [programacion] quedan sin cobertura.
  Evaluacion evaluarProgramacion(Map<int, Alternativa> programacion) {
    final tmin = instancia.holguraMinima;
    final elegidas = programacion.values.toList(growable: false);

    // Cv y Cc: pares de Γ elegidos a la vez; cada par se cuenta una sola vez,
    // en Cv si comparten vehículo y en Cc si solo comparten conductor.
    var cv = 0;
    var cc = 0;
    for (var i = 0; i < elegidas.length; i++) {
      for (var j = i + 1; j < elegidas.length; j++) {
        if (!enConflicto(elegidas[i], elegidas[j], tmin)) continue;
        if (elegidas[i].vehiculoId == elegidas[j].vehiculoId) {
          cv++;
        } else {
          cc++;
        }
      }
    }

    // ℓ_c(X): suma de las duraciones de los servicios de cada conductor.
    final cargas = <int, int>{};
    for (final a in elegidas) {
      cargas[a.conductorId] = (cargas[a.conductorId] ?? 0) + a.duracion;
    }

    // E(X) = Σ máx(0, H_c0 + ℓ_c − H_cmáx) y N_exc.
    var exceso = 0;
    var excedidos = 0;
    cargas.forEach((conductorId, carga) {
      final conductor = instancia.conductores[conductorId];
      if (conductor == null) return;
      final sobra = conductor.acumulado + carga - conductor.limite;
      if (sobra > 0) {
        exceso += sobra;
        excedidos++;
      }
    });

    // Ret(X) y R(X) sobre los servicios con programación comprometida b(s).
    var retraso = 0;
    var reprogramados = 0;
    for (final servicio in instancia.servicios) {
      final comprometida = servicio.comprometida;
      if (comprometida == null) continue;
      final elegida = programacion[servicio.servicioId];
      if (elegida == null) {
        reprogramados++;
        continue;
      }
      retraso += math.max(0, elegida.inicio - comprometida.inicio);
      if (!elegida.mismaQue(comprometida)) reprogramados++;
    }

    // Tm(X): inactividad entre servicios consecutivos del mismo vehículo.
    final porVehiculo = <int, List<Alternativa>>{};
    for (final a in elegidas) {
      porVehiculo.putIfAbsent(a.vehiculoId, () => []).add(a);
    }
    var tiempoMuerto = 0;
    for (final lista in porVehiculo.values) {
      lista.sort((a, b) => a.inicio.compareTo(b.inicio));
      for (var k = 1; k < lista.length; k++) {
        tiempoMuerto += math.max(0, lista[k].inicio - lista[k - 1].fin);
      }
    }

    // D(X): desviación estándar poblacional de ℓ_c entre los conductores con
    // al menos un servicio.
    var desviacion = 0.0;
    if (cargas.isNotEmpty) {
      final media = cargas.values.fold(0, (s, x) => s + x) / cargas.length;
      final varianza =
          cargas.values.fold(0.0, (s, x) => s + (x - media) * (x - media)) / cargas.length;
      desviacion = math.sqrt(varianza);
    }

    // J(X), ecuación (8).
    final w = instancia.pesos;
    final b = instancia.referencias;
    final perdida = w.retraso * retraso / b.retraso +
        w.reprogramacion * reprogramados / b.reprogramacion +
        w.tiempoMuerto * tiempoMuerto / b.tiempoMuerto +
        w.desequilibrio * desviacion / b.desequilibrio;

    final componentes = ComponentesAptitud(
      conflictosVehiculo: cv,
      conflictosConductor: cc,
      conductoresExcedidos: excedidos,
      excesoMin: exceso,
      retrasoMin: retraso,
      reprogramados: reprogramados,
      tiempoMuertoMin: tiempoMuerto,
      desviacionCarga: desviacion,
      perdida: perdida,
    );
    return Evaluacion(
      aptitud: -(instancia.penalizacion * componentes.phi + exceso + perdida),
      componentes: componentes,
      cargas: cargas,
    );
  }
}
