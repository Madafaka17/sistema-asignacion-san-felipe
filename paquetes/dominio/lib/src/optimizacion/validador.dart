/// Validador independiente de las restricciones duras (RNF-01).
///
/// Recalcula `Φ` a partir de los intervalos de las asignaciones, sin usar el
/// evaluador ni el predicado `γ`, para comprobar de forma separada lo que
/// entrega el módulo de optimización y lo que deja un ajuste manual.
library;

/// Asignación que se valida: un servicio cubierto en `[inicio, fin)`.
class AsignacionValidable {
  const AsignacionValidable({
    required this.servicioId,
    required this.vehiculoId,
    required this.conductorId,
    required this.inicio,
    required this.fin,
  });

  final int servicioId;
  final int vehiculoId;
  final int conductorId;
  final int inicio;
  final int fin;
}

/// Límite de conducción de un conductor: `H_c0` y `H_cmáx`.
class LimiteConduccion {
  const LimiteConduccion(this.acumulado, this.limite);

  final int acumulado;
  final int limite;
}

/// Cruce entre dos servicios que comparten un recurso.
class Cruce {
  const Cruce(this.servicioA, this.servicioB, {required this.porVehiculo, required this.recursoId});

  final int servicioA;
  final int servicioB;

  /// `true` si comparten vehículo; `false` si comparten conductor.
  final bool porVehiculo;
  final int recursoId;
}

class ResultadoValidacion {
  const ResultadoValidacion({required this.cruces, required this.conductoresExcedidos});

  /// Pares de servicios en conflicto, cada par una sola vez.
  final List<Cruce> cruces;

  /// Conductores que superan `H_cmáx` → minutos totales `H_c0 + ℓ_c`.
  final Map<int, int> conductoresExcedidos;

  /// `Φ = |pares en conflicto| + N_exc`.
  int get phi => cruces.length + conductoresExcedidos.length;

  bool get esFactible => phi == 0;

  Set<int> get serviciosEnCruce => {for (final c in cruces) ...[c.servicioA, c.servicioB]};
}

class Validador {
  const Validador({required this.holguraMinima});

  final int holguraMinima;

  ResultadoValidacion validar(
    List<AsignacionValidable> asignaciones,
    Map<int, LimiteConduccion> limites,
  ) {
    final pares = <(int, int), Cruce>{};

    void barrer(Map<int, List<AsignacionValidable>> porRecurso, {required bool porVehiculo}) {
      porRecurso.forEach((recursoId, lista) {
        lista.sort((a, b) => a.inicio.compareTo(b.inicio));
        for (var i = 0; i < lista.length; i++) {
          // Como la lista está ordenada por inicio, el servicio j se cruza con
          // el i solo si empieza antes de que i termine más la holgura.
          for (var j = i + 1; j < lista.length && lista[j].inicio < lista[i].fin + holguraMinima; j++) {
            final a = lista[i].servicioId;
            final b = lista[j].servicioId;
            final clave = a < b ? (a, b) : (b, a);
            pares.putIfAbsent(
              clave,
              () => Cruce(clave.$1, clave.$2, porVehiculo: porVehiculo, recursoId: recursoId),
            );
          }
        }
      });
    }

    final porVehiculo = <int, List<AsignacionValidable>>{};
    final porConductor = <int, List<AsignacionValidable>>{};
    final cargas = <int, int>{};
    for (final a in asignaciones) {
      porVehiculo.putIfAbsent(a.vehiculoId, () => []).add(a);
      porConductor.putIfAbsent(a.conductorId, () => []).add(a);
      cargas[a.conductorId] = (cargas[a.conductorId] ?? 0) + (a.fin - a.inicio);
    }
    barrer(porVehiculo, porVehiculo: true);
    barrer(porConductor, porVehiculo: false);

    final excedidos = <int, int>{};
    cargas.forEach((conductorId, carga) {
      final limite = limites[conductorId];
      if (limite != null && limite.acumulado + carga > limite.limite) {
        excedidos[conductorId] = limite.acumulado + carga;
      }
    });
    return ResultadoValidacion(cruces: pares.values.toList(), conductoresExcedidos: excedidos);
  }
}
