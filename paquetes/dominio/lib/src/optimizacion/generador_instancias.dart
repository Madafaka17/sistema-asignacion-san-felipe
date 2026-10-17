import 'dart:math' as math;

import 'instancia.dart';

/// Genera instancias sintéticas con la estructura de las pruebas de concepto
/// de la tesis (Tabla 17), con semilla fija para que sean reproducibles:
///
/// * `|V| = |C| = máx(2, redondeo(n/3))`.
/// * Duraciones enteras uniformes en [40, 120] min y `t_mín` = 10 min.
/// * Entre 2 y 5 alternativas por servicio.
/// * Factibilidad garantizada: cada instancia contiene una programación
///   oculta sin conflictos; el límite de conducción es la carga oculta más
///   una holgura uniforme en [20, 120] min.
/// * El 40 % de los servicios tiene una programación comprometida elegida al
///   azar (base de `Ret` y `R`).
class GeneradorInstancias {
  const GeneradorInstancias._();

  static InstanciaTurno generar({
    required int servicios,
    required int semilla,
    int holguraMinima = 10,
    double proporcionComprometida = 0.4,
  }) {
    final aleatorio = math.Random(semilla);
    final m = math.max(2, (servicios / 3).round());
    final cursores = List.filled(m, 0);
    final cargaOculta = List.filled(m, 0);
    final lista = <ServicioTurno>[];

    for (var k = 0; k < servicios; k++) {
      // Programación oculta: el recurso r (vehículo r y conductor r) que
      // queda libre primero toma el servicio.
      var r = 0;
      for (var i = 1; i < m; i++) {
        if (cursores[i] < cursores[r]) r = i;
      }
      final duracion = 40 + aleatorio.nextInt(81);
      final inicio = cursores[r];
      cursores[r] = inicio + duracion + holguraMinima + aleatorio.nextInt(31);
      cargaOculta[r] += duracion;

      final oculta = Alternativa(vehiculoId: r + 1, conductorId: r + 1, salida: inicio, duracion: duracion);
      final alternativas = <Alternativa>[oculta];
      final extras = 1 + aleatorio.nextInt(4);
      for (var e = 0; e < extras; e++) {
        final candidata = Alternativa(
          vehiculoId: 1 + aleatorio.nextInt(m),
          conductorId: 1 + aleatorio.nextInt(m),
          salida: math.max(0, inicio + aleatorio.nextInt(61) - 30),
          duracion: duracion,
        );
        if (!alternativas.any(candidata.mismaQue)) alternativas.add(candidata);
      }
      alternativas.sort((a, b) {
        if (a.salida != b.salida) return a.salida.compareTo(b.salida);
        if (a.vehiculoId != b.vehiculoId) return a.vehiculoId.compareTo(b.vehiculoId);
        return a.conductorId.compareTo(b.conductorId);
      });
      final comprometida = aleatorio.nextDouble() < proporcionComprometida
          ? alternativas[aleatorio.nextInt(alternativas.length)]
          : null;
      lista.add(ServicioTurno(
        servicioId: k + 1,
        codigo: 'S${(k + 1).toString().padLeft(3, '0')}',
        codigoRuta: 'R01',
        prioridad: 1 + aleatorio.nextInt(3),
        capacidadRequerida: 1,
        alternativas: alternativas,
        comprometida: comprometida,
      ));
    }

    final comprometidos = lista.where((s) => s.comprometida != null).length;
    return InstanciaTurno(
      fecha: DateTime.utc(2026, 11, 12),
      servicios: lista,
      conductores: {
        for (var r = 0; r < m; r++)
          r + 1: ConductorTurno(
            id: r + 1,
            codigo: 'C${(r + 1).toString().padLeft(2, '0')}',
            acumulado: 0,
            limite: cargaOculta[r] + 20 + aleatorio.nextInt(101),
          ),
      },
      codigosVehiculo: {for (var r = 0; r < m; r++) r + 1: 'V${(r + 1).toString().padLeft(2, '0')}'},
      holguraMinima: holguraMinima,
      pesos: const PesosPerdida(),
      referencias: ReferenciasPerdida(
        retraso: 60,
        reprogramacion: comprometidos == 0 ? 1 : comprometidos.toDouble(),
        tiempoMuerto: 60.0 * m,
        desequilibrio: 60,
      ),
    );
  }
}
