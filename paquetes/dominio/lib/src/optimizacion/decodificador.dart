import '../modelos/tiempo.dart';
import 'evaluador.dart';
import 'instancia.dart';

/// Resultado de un servicio en la programación propuesta.
class ResultadoServicio {
  const ResultadoServicio.asignado(this.servicio, Alternativa this.alternativa) : motivo = null;

  const ResultadoServicio.incidencia(this.servicio, String this.motivo) : alternativa = null;

  final ServicioTurno servicio;

  /// Alternativa elegida; `null` si el servicio quedó como incidencia.
  final Alternativa? alternativa;
  final String? motivo;

  bool get asignado => alternativa != null;
}

/// Convierte el mejor cromosoma en la programación que se propone al
/// encargado de operaciones.
///
/// Los servicios con `A_s = ∅` se reportan como incidencia (`u_s = 1`). Si
/// la reparación dejó conflictos residuales (`Φ > 0`), el servicio de menor
/// prioridad de cada conflicto, y en el exceso de conducción los servicios de
/// menor prioridad del conductor, también se reportan como incidencia en
/// lugar de forzar una asignación inválida (sección 3.4.9). Así las
/// asignaciones que quedan cumplen `Φ = 0` (RNF-01).
class Decodificador {
  const Decodificador(this.instancia);

  final InstanciaTurno instancia;

  List<ResultadoServicio> decodificar(List<int> cromosoma) {
    final tmin = instancia.holguraMinima;
    final elegidas = <int, Alternativa>{
      for (var i = 0; i < cromosoma.length; i++) i: instancia.admisibles[i].alternativas[cromosoma[i]],
    };
    final motivos = <int, String>{};

    ServicioTurno servicio(int i) => instancia.admisibles[i];

    // Indice de la víctima: menor prioridad; en empate, inicio más tardío;
    // en empate, mayor índice.
    int victima(int i, int j) {
      final pi = servicio(i).prioridad;
      final pj = servicio(j).prioridad;
      if (pi != pj) return pi < pj ? i : j;
      final ti = elegidas[i]!.inicio;
      final tj = elegidas[j]!.inicio;
      if (ti != tj) return ti > tj ? i : j;
      return i > j ? i : j;
    }

    // Conflictos residuales de Γ.
    var hayCruce = true;
    while (hayCruce) {
      hayCruce = false;
      final activos = elegidas.keys.toList()..sort();
      buscar:
      for (var x = 0; x < activos.length; x++) {
        for (var y = x + 1; y < activos.length; y++) {
          final i = activos[x];
          final j = activos[y];
          final a = elegidas[i]!;
          final b = elegidas[j]!;
          if (!enConflicto(a, b, tmin)) continue;
          final v = victima(i, j);
          final otro = v == i ? j : i;
          final recurso = a.vehiculoId == b.vehiculoId
              ? 'el vehículo ${instancia.codigosVehiculo[a.vehiculoId] ?? a.vehiculoId}'
              : 'el conductor ${instancia.conductores[a.conductorId]?.codigo ?? a.conductorId}';
          motivos[v] = 'Cruce con ${servicio(otro).codigo} por $recurso y no hay otra '
              'alternativa libre';
          elegidas.remove(v);
          hayCruce = true;
          break buscar;
        }
      }
    }

    // Exceso del límite de conducción.
    final conductores = instancia.conductores.keys.toList()..sort();
    for (final conductorId in conductores) {
      final conductor = instancia.conductores[conductorId]!;
      while (true) {
        final propios = [
          for (final e in elegidas.entries)
            if (e.value.conductorId == conductorId) e.key,
        ];
        final carga = propios.fold(0, (s, i) => s + elegidas[i]!.duracion);
        if (conductor.acumulado + carga <= conductor.limite) break;
        final v = propios.reduce(victima);
        motivos[v] = 'Supera el límite de conducción de ${conductor.codigo} '
            '(${conductor.acumulado + carga} > ${conductor.limite} min) y ningún otro '
            'conductor puede cubrir el servicio a las ${minutosAHora(elegidas[v]!.salida)}';
        elegidas.remove(v);
      }
    }

    final posicion = {
      for (var i = 0; i < instancia.admisibles.length; i++) instancia.admisibles[i].servicioId: i,
    };
    return [
      for (final s in instancia.servicios)
        if (!s.tieneAlternativas)
          ResultadoServicio.incidencia(s, s.motivoSinAlternativas ?? 'Sin alternativas admisibles')
        else if (elegidas[posicion[s.servicioId]!] case final alternativa?)
          ResultadoServicio.asignado(s, alternativa)
        else
          ResultadoServicio.incidencia(s, motivos[posicion[s.servicioId]!]!),
    ];
  }
}
