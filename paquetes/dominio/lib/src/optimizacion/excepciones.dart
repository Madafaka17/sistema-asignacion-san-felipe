import 'instancia.dart';

/// Salidas `σ(s)`, `η(s)` y `Δt(s)` de la Tabla 11 para la alternativa
/// elegida de un servicio.
///
/// No intervienen en `F(X)`: `A_s` ya acota los saltos de cola y los
/// reemplazos (ecuación 1) y estas salidas los hacen visibles para que el
/// encargado de operaciones los revise (secciones 3.1.2 y 3.6).
class ExcepcionesAsignacion {
  const ExcepcionesAsignacion({
    this.saltoCola = false,
    this.reemplazo = false,
    this.demoraMin = 0,
    this.vehiculoCola,
    this.conductorHabitual,
    this.explicacion,
  });

  factory ExcepcionesAsignacion.de(InstanciaTurno instancia, ServicioTurno servicio, Alternativa a) {
    final v0 = servicio.vehiculoCola;
    final habitual = instancia.habituales[a.vehiculoId];
    final salto = v0 != null && a.vehiculoId != v0;
    final reemplazo = habitual != null && a.conductorId != habitual;
    final nominal = servicio.nominal;

    String vehiculo(int id) => instancia.codigosVehiculo[id] ?? 'V$id';
    String conductor(int id) => instancia.codigosConductor[id] ?? instancia.conductores[id]?.codigo ?? 'C$id';

    final partes = [
      if (salto)
        servicio.alternativas.any((x) => x.vehiculoId == v0)
            ? 'salto de cola: la unidad que corresponde (${vehiculo(v0)}) es admisible, pero '
                'la siguiente evita un cruce o mejora F(X)'
            : 'salto de cola: la unidad que corresponde (${vehiculo(v0)}) no está disponible, '
                'dejó la cola o no tiene un conductor autorizado para el servicio',
      if (reemplazo)
        servicio.alternativas.any((x) => x.vehiculoId == a.vehiculoId && x.conductorId == habitual)
            ? 'reemplazo: el conductor habitual (${conductor(habitual)}) es admisible, pero '
                'el reemplazo evita un cruce o un exceso de conducción, o mejora F(X)'
            : 'reemplazo: el conductor habitual (${conductor(habitual)}) no está disponible, '
                'no tiene licencia habilitante o su turno no cubre el servicio',
    ];
    return ExcepcionesAsignacion(
      saltoCola: salto,
      reemplazo: reemplazo,
      demoraMin: nominal == null || a.salida <= nominal ? 0 : a.salida - nominal,
      vehiculoCola: v0,
      conductorHabitual: habitual,
      explicacion: partes.isEmpty ? null : 'Propuesta del sistema — ${partes.join('; ')}',
    );
  }

  /// `σ(s)`.
  final bool saltoCola;

  /// `η(s)`.
  final bool reemplazo;

  /// `Δt(s)`, en minutos.
  final int demoraMin;

  /// `v0(s)` y `chab(v)` de la unidad elegida.
  final int? vehiculoCola;
  final int? conductorHabitual;

  /// Por qué el módulo de optimización propone el salto o el reemplazo.
  final String? explicacion;

  /// Un salto de cola o un reemplazo introducido a mano exige un motivo.
  bool get requiereJustificacion => saltoCola || reemplazo;
}
