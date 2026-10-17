import '../contrato/lector_json.dart';

/// Relación entre una unidad y un conductor que puede conducirla
/// (sección 3.1.2 de la tesis).
enum TipoPar {
  /// `chab(v)`: conductor habitual de la unidad; se prioriza.
  habitual('habitual', 'Conductor habitual'),

  /// Elemento de `C_v^R`: reemplazo autorizado.
  reemplazo('reemplazo', 'Reemplazo autorizado');

  const TipoPar(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static TipoPar desdeValor(String valor) => TipoPar.values.firstWhere((t) => t.valor == valor);
}

/// Par autorizado unidad–conductor.
class ParAutorizado {
  const ParAutorizado({required this.vehiculoId, required this.conductorId, required this.tipo});

  final int vehiculoId;
  final int conductorId;
  final TipoPar tipo;

  Map<String, Object?> toJson() => {'vehiculoId': vehiculoId, 'conductorId': conductorId, 'tipo': tipo.valor};

  factory ParAutorizado.fromJson(Object? json) {
    final l = LectorJson(json);
    final par = ParAutorizado(
      vehiculoId: l.entero('vehiculoId'),
      conductorId: l.entero('conductorId'),
      tipo: l.enumeracion('tipo', TipoPar.values, (t) => t.valor),
    );
    l.verificar();
    return par;
  }
}

/// Conductores que pueden conducir una unidad: `chab(v)` y `C_v^R`.
///
/// Es el cuerpo de `PUT /api/vehiculos/{id}/conductores`, que reemplaza el
/// conjunto completo de la unidad.
class ConductoresAutorizados {
  const ConductoresAutorizados({
    this.vehiculoId = 0,
    this.conductorHabitualId,
    this.reemplazos = const [],
  });

  final int vehiculoId;
  final int? conductorHabitualId;
  final List<int> reemplazos;

  bool get vacio => conductorHabitualId == null && reemplazos.isEmpty;

  /// `{chab(v)} ∪ C_v^R`.
  Set<int> get todos => {?conductorHabitualId, ...reemplazos};

  List<ParAutorizado> get pares => [
        if (conductorHabitualId case final habitual?)
          ParAutorizado(vehiculoId: vehiculoId, conductorId: habitual, tipo: TipoPar.habitual),
        for (final c in reemplazos) ParAutorizado(vehiculoId: vehiculoId, conductorId: c, tipo: TipoPar.reemplazo),
      ];

  /// Agrupa los pares por unidad.
  static Map<int, ConductoresAutorizados> porVehiculo(Iterable<ParAutorizado> pares) {
    final habitual = <int, int>{};
    final reemplazos = <int, List<int>>{};
    for (final p in pares) {
      if (p.tipo == TipoPar.habitual) {
        habitual[p.vehiculoId] = p.conductorId;
      } else {
        reemplazos.putIfAbsent(p.vehiculoId, () => []).add(p.conductorId);
      }
    }
    return {
      for (final v in {...habitual.keys, ...reemplazos.keys})
        v: ConductoresAutorizados(
          vehiculoId: v,
          conductorHabitualId: habitual[v],
          reemplazos: [...?reemplazos[v]]..sort(),
        ),
    };
  }

  Map<String, Object?> toJson() => {
        'vehiculoId': vehiculoId,
        'conductorHabitualId': conductorHabitualId,
        'reemplazos': reemplazos,
      };

  factory ConductoresAutorizados.fromJson(Object? json) {
    final l = LectorJson(json);
    final autorizados = ConductoresAutorizados(
      vehiculoId: l.enteroOpcional('vehiculoId') ?? 0,
      conductorHabitualId: l.enteroOpcional('conductorHabitualId'),
      reemplazos: l.listaEnteros('reemplazos'),
    );
    l.verificar();
    return autorizados;
  }
}
