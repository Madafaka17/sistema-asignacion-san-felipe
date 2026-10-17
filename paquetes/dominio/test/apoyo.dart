import 'package:dominio/dominio.dart';

/// Instancia de la Tabla 21 de la tesis (cuatro servicios, t_mín = 10 min).
///
/// | Servicio | Ruta; duración | Alternativas (vehículo, conductor, salida) |
/// |----------|----------------|--------------------------------------------|
/// | S01      | R02; 120 min   | 0: (V01, C03, 06:00) 1: (V02, C01, 06:15)  |
/// | S02      | R01; 90 min    | 0: (V04, C01, 06:15) 1: (V03, C02, 06:30) 2: (V04, C05, 06:45) |
/// | S03      | R03; 60 min    | 0: (V02, C05, 06:30) 1: (V03, C05, 07:00)  |
/// | S04      | R02; 120 min   | 0: (V01, C03, 08:15) 1: (V02, C04, 08:30) 2: (V03, C03, 08:45) |
InstanciaTurno instanciaTabla21({Map<int, int> limites = const {}, int prioridadS03 = 2}) {
  Alternativa a(int v, int c, String hora, int d) =>
      Alternativa(vehiculoId: v, conductorId: c, salida: horaAMinutos(hora)!, duracion: d);
  final servicios = [
    ServicioTurno(
      servicioId: 1,
      codigo: 'S01',
      codigoRuta: 'R02',
      prioridad: 2,
      capacidadRequerida: 1,
      alternativas: [a(1, 3, '06:00', 120), a(2, 1, '06:15', 120)],
    ),
    ServicioTurno(
      servicioId: 2,
      codigo: 'S02',
      codigoRuta: 'R01',
      prioridad: 2,
      capacidadRequerida: 1,
      alternativas: [a(4, 1, '06:15', 90), a(3, 2, '06:30', 90), a(4, 5, '06:45', 90)],
    ),
    ServicioTurno(
      servicioId: 3,
      codigo: 'S03',
      codigoRuta: 'R03',
      prioridad: prioridadS03,
      capacidadRequerida: 1,
      alternativas: [a(2, 5, '06:30', 60), a(3, 5, '07:00', 60)],
    ),
    ServicioTurno(
      servicioId: 4,
      codigo: 'S04',
      codigoRuta: 'R02',
      prioridad: 2,
      capacidadRequerida: 1,
      alternativas: [a(1, 3, '08:15', 120), a(2, 4, '08:30', 120), a(3, 3, '08:45', 120)],
    ),
  ];
  return InstanciaTurno(
    fecha: DateTime.utc(2026, 11, 12),
    servicios: servicios,
    conductores: {
      for (final c in [1, 2, 3, 4, 5])
        c: ConductorTurno(id: c, codigo: 'C0$c', acumulado: 0, limite: limites[c] ?? 600),
    },
    codigosVehiculo: {for (final v in [1, 2, 3, 4]) v: 'V0$v'},
    holguraMinima: 10,
    pesos: const PesosPerdida(),
    referencias: const ReferenciasPerdida(
      retraso: 60,
      reprogramacion: 1,
      tiempoMuerto: 240,
      desequilibrio: 60,
    ),
  );
}

/// Óptimo exacto por enumeración exhaustiva de `Π |A_s|` cromosomas.
(List<int>, double) optimoExhaustivo(InstanciaTurno instancia) {
  final evaluador = Evaluador(instancia);
  final tamanos = [for (final s in instancia.admisibles) s.alternativas.length];
  final actual = List.filled(tamanos.length, 0);
  var mejor = List.of(actual);
  var mejorAptitud = evaluador.evaluar(actual).aptitud;
  while (true) {
    var i = 0;
    while (i < actual.length && ++actual[i] == tamanos[i]) {
      actual[i] = 0;
      i++;
    }
    if (i == actual.length) break;
    final aptitud = evaluador.evaluar(actual).aptitud;
    if (aptitud > mejorAptitud) {
      mejorAptitud = aptitud;
      mejor = List.of(actual);
    }
  }
  return (mejor, mejorAptitud);
}

/// Convierte un cromosoma en asignaciones para el validador independiente.
List<AsignacionValidable> comoValidables(InstanciaTurno instancia, List<int> cromosoma) => [
      for (var i = 0; i < cromosoma.length; i++)
        () {
          final a = instancia.admisibles[i].alternativas[cromosoma[i]];
          return AsignacionValidable(
            servicioId: instancia.admisibles[i].servicioId,
            vehiculoId: a.vehiculoId,
            conductorId: a.conductorId,
            inicio: a.inicio,
            fin: a.fin,
          );
        }(),
    ];

Map<int, LimiteConduccion> limitesDe(InstanciaTurno instancia) => {
      for (final c in instancia.conductores.values) c.id: LimiteConduccion(c.acumulado, c.limite),
    };
