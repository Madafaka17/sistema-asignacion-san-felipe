import '../infraestructura/base_datos.dart';

/// Conteos de un periodo para los indicadores de la sección 3.5.
class DatosIndicadores {
  const DatosIndicadores({
    required this.programacionesAprobadas,
    required this.serviciosProgramados,
    required this.minutosServicio,
    required this.minutosDisponibles,
    required this.desviacionPromedio,
    required this.programacionesGeneradas,
    required this.asignacionesGeneradas,
    required this.asignacionesSinConflicto,
    required this.tiempoGeneracionPromedioMs,
    required this.incidenciasPorTipo,
    this.reemplazos = 0,
    this.saltosCola = 0,
    this.salidasDemoradas = 0,
    this.minutosDemora = 0,
    this.retrasoMin = 0,
    this.tiempoMuertoMin = 0,
  });

  final int programacionesAprobadas;
  final int serviciosProgramados;
  final int minutosServicio;
  final int minutosDisponibles;
  final double desviacionPromedio;
  final int programacionesGeneradas;
  final int asignacionesGeneradas;
  final int asignacionesSinConflicto;
  final double tiempoGeneracionPromedioMs;
  final Map<String, int> incidenciasPorTipo;

  /// Indicadores operativos de las programaciones aprobadas (Tabla 24).
  final int reemplazos;
  final int saltosCola;
  final int salidasDemoradas;
  final int minutosDemora;
  final int retrasoMin;
  final int tiempoMuertoMin;
}

abstract interface class RepositorioReportes {
  Future<DatosIndicadores> datos(DateTime desde, DateTime hasta, {required int minutosDisponiblesVehiculo});
}

class RepositorioReportesMysql implements RepositorioReportes {
  const RepositorioReportesMysql(this._bd);

  final BaseDatos _bd;

  @override
  Future<DatosIndicadores> datos(DateTime desde, DateTime hasta, {required int minutosDisponiblesVehiculo}) async {
    final periodo = {'desde': formatoFecha(desde), 'hasta': formatoFecha(hasta), 'disponible': minutosDisponiblesVehiculo};

    // Programaciones aprobadas (vigentes) del periodo: servicios programados,
    // tiempo de servicio de los vehículos y tiempo disponible.
    final aprobadas = (await _bd.consultar(
      'SELECT COUNT(*) AS programaciones, COALESCE(SUM(vehiculos_disponibles * :disponible), 0) AS disponibles, '
      'COALESCE(AVG(desviacion_carga), 0) AS desviacion, COALESCE(SUM(retraso_min), 0) AS retraso, '
      'COALESCE(SUM(tiempo_muerto_min), 0) AS tiempo_muerto FROM programacion '
      "WHERE fecha BETWEEN :desde AND :hasta AND estado = 'aprobada'",
      periodo,
    ))
        .single;
    final servicios = (await _bd.consultar(
      'SELECT COUNT(*) AS servicios, COALESCE(SUM(a.fin - a.salida), 0) AS minutos, '
      'COALESCE(SUM(a.reemplazo), 0) AS reemplazos, COALESCE(SUM(a.salto_cola), 0) AS saltos, '
      'COALESCE(SUM(a.demora_min > 0), 0) AS demoradas, COALESCE(SUM(a.demora_min), 0) AS demora FROM asignacion a '
      'JOIN programacion p ON p.id = a.programacion_id '
      "WHERE p.fecha BETWEEN :desde AND :hasta AND p.estado = 'aprobada' AND a.estado = 'asignado'",
      periodo,
    ))
        .single;

    // Todas las programaciones generadas en el periodo: PAV y tiempo medio.
    final generadas = (await _bd.consultar(
      'SELECT COUNT(DISTINCT p.id) AS programaciones, COUNT(a.id) AS asignaciones, '
      "COALESCE(SUM(a.estado = 'asignado'), 0) AS sin_conflicto FROM programacion p "
      'LEFT JOIN asignacion a ON a.programacion_id = p.id WHERE p.fecha BETWEEN :desde AND :hasta',
      periodo,
    ))
        .single;
    final tiempo = (await _bd.consultar(
      'SELECT COALESCE(AVG(tiempo_ms), 0) AS ms FROM programacion WHERE fecha BETWEEN :desde AND :hasta',
      periodo,
    ))
        .single;

    final incidencias = await _bd.consultar(
      'SELECT tipo, COUNT(*) AS n FROM incidencia WHERE fecha BETWEEN :desde AND :hasta GROUP BY tipo',
      periodo,
    );

    return DatosIndicadores(
      programacionesAprobadas: aprobadas.entero('programaciones'),
      serviciosProgramados: servicios.entero('servicios'),
      minutosServicio: double.parse(servicios.texto('minutos')).round(),
      minutosDisponibles: double.parse(aprobadas.texto('disponibles')).round(),
      desviacionPromedio: aprobadas.decimal('desviacion'),
      programacionesGeneradas: generadas.entero('programaciones'),
      asignacionesGeneradas: generadas.entero('asignaciones'),
      asignacionesSinConflicto: double.parse(generadas.texto('sin_conflicto')).round(),
      tiempoGeneracionPromedioMs: tiempo.decimal('ms'),
      incidenciasPorTipo: {for (final f in incidencias) f.texto('tipo'): f.entero('n')},
      reemplazos: _suma(servicios, 'reemplazos'),
      saltosCola: _suma(servicios, 'saltos'),
      salidasDemoradas: _suma(servicios, 'demoradas'),
      minutosDemora: _suma(servicios, 'demora'),
      retrasoMin: _suma(aprobadas, 'retraso'),
      tiempoMuertoMin: _suma(aprobadas, 'tiempo_muerto'),
    );
  }

  /// `SUM` de MySQL devuelve DECIMAL.
  static int _suma(Fila f, String columna) => double.parse(f.texto(columna)).round();
}
