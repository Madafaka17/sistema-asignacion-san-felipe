import 'tiempo.dart';

/// Indicadores de la sección 3.5 de la tesis (ecuaciones 19 a 23).
///
/// Todas devuelven un porcentaje entre 0 y 100, o `0` cuando el
/// denominador es 0.
class Indicadores {
  const Indicadores._();

  static double _porcentaje(num numerador, num denominador) =>
      denominador == 0 ? 0 : numerador / denominador * 100;

  /// (19) PIO = (vehículos + conductores con asignación inadecuada)
  /// / servicios programados × 100.
  static double pio(int vehiculosInadecuados, int conductoresInadecuados, int programados) =>
      _porcentaje(vehiculosInadecuados + conductoresInadecuados, programados);

  /// (20) PSR = servicios reprogramados / servicios programados × 100.
  static double psr(int reprogramados, int programados) => _porcentaje(reprogramados, programados);

  /// (21) PSA = servicios con retraso / servicios programados × 100.
  static double psa(int conRetraso, int programados) => _porcentaje(conRetraso, programados);

  /// (22) PUV = tiempo de servicio de los vehículos / tiempo disponible × 100.
  static double puv(int minutosServicio, int minutosDisponibles) =>
      _porcentaje(minutosServicio, minutosDisponibles);

  /// (23) PAV = asignaciones sin conflicto / asignaciones generadas × 100.
  static double pav(int sinConflicto, int generadas) => _porcentaje(sinConflicto, generadas);

  /// Redondeo a un decimal para la presentación (6.315… → 6.3).
  static double redondear(double valor) => (valor * 10).roundToDouble() / 10;
}

/// Reporte de indicadores de un periodo (HU-11).
class ReporteIndicadores {
  const ReporteIndicadores({
    required this.desde,
    required this.hasta,
    this.sinDatos = false,
    this.serviciosProgramados = 0,
    this.reprogramados = 0,
    this.conRetraso = 0,
    this.vehiculosInadecuados = 0,
    this.conductoresInadecuados = 0,
    this.pio = 0,
    this.psr = 0,
    this.psa = 0,
    this.puv = 0,
    this.pav = 0,
    this.desviacionCarga = 0,
    this.tiempoGeneracionPromedioS = 0,
    this.programacionesGeneradas = 0,
  });

  /// Reporte de un periodo en el que no hay programaciones aprobadas.
  const ReporteIndicadores.vacio(this.desde, this.hasta)
      : sinDatos = true,
        serviciosProgramados = 0,
        reprogramados = 0,
        conRetraso = 0,
        vehiculosInadecuados = 0,
        conductoresInadecuados = 0,
        pio = 0,
        psr = 0,
        psa = 0,
        puv = 0,
        pav = 0,
        desviacionCarga = 0,
        tiempoGeneracionPromedioS = 0,
        programacionesGeneradas = 0;

  static const mensajeSinDatos = 'Sin datos para el periodo';

  final DateTime desde;
  final DateTime hasta;
  final bool sinDatos;
  final int serviciosProgramados;
  final int reprogramados;
  final int conRetraso;
  final int vehiculosInadecuados;
  final int conductoresInadecuados;
  final double pio;
  final double psr;
  final double psa;
  final double puv;
  final double pav;

  /// Promedio de `D(X)` de las programaciones aprobadas, en minutos.
  final double desviacionCarga;
  final double tiempoGeneracionPromedioS;
  final int programacionesGeneradas;

  Map<String, Object?> toJson() => {
        'desde': fechaATexto(desde),
        'hasta': fechaATexto(hasta),
        'sinDatos': sinDatos,
        if (sinDatos) 'mensaje': mensajeSinDatos,
        'serviciosProgramados': serviciosProgramados,
        'reprogramados': reprogramados,
        'conRetraso': conRetraso,
        'vehiculosInadecuados': vehiculosInadecuados,
        'conductoresInadecuados': conductoresInadecuados,
        'pio': pio,
        'psr': psr,
        'psa': psa,
        'puv': puv,
        'pav': pav,
        'desviacionCarga': desviacionCarga,
        'tiempoGeneracionPromedioS': tiempoGeneracionPromedioS,
        'programacionesGeneradas': programacionesGeneradas,
      };

  factory ReporteIndicadores.fromJson(Map<String, Object?> json) {
    double d(String k) => (json[k] as num).toDouble();
    return ReporteIndicadores(
      desde: textoAFecha(json['desde'] as String),
      hasta: textoAFecha(json['hasta'] as String),
      sinDatos: json['sinDatos'] as bool,
      serviciosProgramados: json['serviciosProgramados'] as int,
      reprogramados: json['reprogramados'] as int,
      conRetraso: json['conRetraso'] as int,
      vehiculosInadecuados: json['vehiculosInadecuados'] as int,
      conductoresInadecuados: json['conductoresInadecuados'] as int,
      pio: d('pio'),
      psr: d('psr'),
      psa: d('psa'),
      puv: d('puv'),
      pav: d('pav'),
      desviacionCarga: d('desviacionCarga'),
      tiempoGeneracionPromedioS: d('tiempoGeneracionPromedioS'),
      programacionesGeneradas: json['programacionesGeneradas'] as int,
    );
  }
}
