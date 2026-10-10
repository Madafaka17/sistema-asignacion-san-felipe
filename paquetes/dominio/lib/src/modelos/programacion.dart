import '../contrato/lector_json.dart';
import 'tiempo.dart';

enum EstadoProgramacion {
  /// Generada por el método y pendiente de revisión (HU-07, HU-08).
  propuesta('propuesta', 'Propuesta'),

  /// Confirmada por el encargado de operaciones (HU-09). Vigente.
  aprobada('aprobada', 'Aprobada'),

  /// Fue aprobada y luego la sustituyó otra aprobación de la misma fecha.
  reemplazada('reemplazada', 'Reemplazada'),
  descartada('descartada', 'Descartada');

  const EstadoProgramacion(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoProgramacion desdeValor(String valor) =>
      EstadoProgramacion.values.firstWhere((e) => e.valor == valor);
}

enum EstadoAsignacion {
  /// Cubierto sin incumplir restricciones duras.
  asignado('asignado', 'Asignado'),

  /// Sin cobertura: el servicio no tiene alternativas admisibles o su
  /// asignación incumpliría una restricción dura (incidencia pendiente).
  incidencia('incidencia', 'Incidencia pendiente'),

  /// Un ajuste manual dejó un cruce de vehículo o conductor sin resolver.
  conflicto('conflicto', 'Cruce sin resolver');

  const EstadoAsignacion(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoAsignacion desdeValor(String valor) =>
      EstadoAsignacion.values.firstWhere((e) => e.valor == valor);
}

/// Componentes de la función de aptitud de las ecuaciones (7) y (8).
class ComponentesAptitud {
  const ComponentesAptitud({
    this.conflictosVehiculo = 0,
    this.conflictosConductor = 0,
    this.conductoresExcedidos = 0,
    this.excesoMin = 0,
    this.retrasoMin = 0,
    this.reprogramados = 0,
    this.tiempoMuertoMin = 0,
    this.desviacionCarga = 0,
    this.perdida = 0,
  });

  /// `Cv`, `Cc` y `N_exc`; su suma es `Φ`.
  final int conflictosVehiculo;
  final int conflictosConductor;
  final int conductoresExcedidos;

  /// `E`, en minutos.
  final int excesoMin;

  /// `Ret`, `R`, `Tm` y `D`.
  final int retrasoMin;
  final int reprogramados;
  final int tiempoMuertoMin;
  final double desviacionCarga;

  /// `J`.
  final double perdida;

  int get phi => conflictosVehiculo + conflictosConductor + conductoresExcedidos;

  Map<String, Object?> toJson() => {
        'conflictosVehiculo': conflictosVehiculo,
        'conflictosConductor': conflictosConductor,
        'conductoresExcedidos': conductoresExcedidos,
        'excesoMin': excesoMin,
        'retrasoMin': retrasoMin,
        'reprogramados': reprogramados,
        'tiempoMuertoMin': tiempoMuertoMin,
        'desviacionCarga': desviacionCarga,
        'perdida': perdida,
      };

  factory ComponentesAptitud.fromJson(Map<String, Object?> json) => ComponentesAptitud(
        conflictosVehiculo: json['conflictosVehiculo'] as int,
        conflictosConductor: json['conflictosConductor'] as int,
        conductoresExcedidos: json['conductoresExcedidos'] as int,
        excesoMin: json['excesoMin'] as int,
        retrasoMin: json['retrasoMin'] as int,
        reprogramados: json['reprogramados'] as int,
        tiempoMuertoMin: json['tiempoMuertoMin'] as int,
        desviacionCarga: (json['desviacionCarga'] as num).toDouble(),
        perdida: (json['perdida'] as num).toDouble(),
      );
}

/// Mejor aptitud y aptitud promedio de una generación del algoritmo.
class PuntoConvergencia {
  const PuntoConvergencia(this.generacion, this.mejor, this.promedio);

  final int generacion;
  final double mejor;
  final double promedio;

  Map<String, Object?> toJson() => {'generacion': generacion, 'mejor': mejor, 'promedio': promedio};

  factory PuntoConvergencia.fromJson(Map<String, Object?> json) => PuntoConvergencia(
        json['generacion'] as int,
        (json['mejor'] as num).toDouble(),
        (json['promedio'] as num).toDouble(),
      );
}

/// Asignación de un servicio dentro de una programación (HU-08).
class Asignacion {
  const Asignacion({
    required this.servicioId,
    required this.codigoServicio,
    required this.codigoRuta,
    required this.prioridad,
    this.vehiculoId,
    this.codigoVehiculo,
    this.conductorId,
    this.codigoConductor,
    this.salida,
    this.fin,
    required this.estado,
    this.motivo,
    this.ajustada = false,
  });

  final int servicioId;
  final String codigoServicio;
  final String codigoRuta;
  final int prioridad;
  final int? vehiculoId;
  final String? codigoVehiculo;
  final int? conductorId;
  final String? codigoConductor;

  /// Hora de salida elegida `h` y hora de término `h + d_{s,h}`.
  final int? salida;
  final int? fin;
  final EstadoAsignacion estado;

  /// Motivo de la incidencia o del cruce.
  final String? motivo;

  /// Modificada a mano por el encargado de operaciones (HU-09).
  final bool ajustada;

  bool get tieneRecursos => vehiculoId != null && conductorId != null && salida != null;

  Map<String, Object?> toJson() => {
        'servicioId': servicioId,
        'codigoServicio': codigoServicio,
        'codigoRuta': codigoRuta,
        'prioridad': prioridad,
        'vehiculoId': vehiculoId,
        'codigoVehiculo': codigoVehiculo,
        'conductorId': conductorId,
        'codigoConductor': codigoConductor,
        'salida': salida,
        'fin': fin,
        'estado': estado.valor,
        'motivo': motivo,
        'ajustada': ajustada,
      };

  factory Asignacion.fromJson(Map<String, Object?> json) => Asignacion(
        servicioId: json['servicioId'] as int,
        codigoServicio: json['codigoServicio'] as String,
        codigoRuta: json['codigoRuta'] as String,
        prioridad: json['prioridad'] as int,
        vehiculoId: json['vehiculoId'] as int?,
        codigoVehiculo: json['codigoVehiculo'] as String?,
        conductorId: json['conductorId'] as int?,
        codigoConductor: json['codigoConductor'] as String?,
        salida: json['salida'] as int?,
        fin: json['fin'] as int?,
        estado: EstadoAsignacion.desdeValor(json['estado'] as String),
        motivo: json['motivo'] as String?,
        ajustada: json['ajustada'] as bool,
      );

  /// Orden de la vista de HU-08: primero las incidencias y cruces, luego las
  /// asignaciones por hora de salida.
  static int compararParaVista(Asignacion a, Asignacion b) {
    final pa = a.estado == EstadoAsignacion.asignado ? 1 : 0;
    final pb = b.estado == EstadoAsignacion.asignado ? 1 : 0;
    if (pa != pb) return pa.compareTo(pb);
    final sa = a.salida ?? -1;
    final sb = b.salida ?? -1;
    if (sa != sb) return sa.compareTo(sb);
    return a.codigoServicio.compareTo(b.codigoServicio);
  }
}

/// Programación de un turno, resultado de una ejecución del método (HU-07).
class Programacion {
  const Programacion({
    required this.id,
    required this.fecha,
    required this.estado,
    required this.metodo,
    required this.aptitud,
    required this.phi,
    required this.phiValidador,
    required this.componentes,
    required this.generaciones,
    required this.tiempoMs,
    this.semilla,
    required this.creadoPor,
    required this.creadoEn,
    this.aprobadoPor,
    this.aprobadoEn,
    this.asignaciones = const [],
    this.historial = const [],
  });

  final int id;
  final DateTime fecha;
  final EstadoProgramacion estado;

  /// Identificador de la estrategia de optimización usada.
  final String metodo;

  /// `F(X)` y `Φ(X)` de la mejor solución del método.
  final double aptitud;
  final int phi;

  /// `Φ` que recalcula el validador independiente sobre las asignaciones
  /// vigentes; debe ser 0 para poder aprobar (RNF-01).
  final int phiValidador;
  final ComponentesAptitud componentes;
  final int generaciones;
  final int tiempoMs;
  final int? semilla;
  final String creadoPor;
  final DateTime creadoEn;
  final String? aprobadoPor;
  final DateTime? aprobadoEn;
  final List<Asignacion> asignaciones;
  final List<PuntoConvergencia> historial;

  int get asignados => asignaciones.where((a) => a.estado == EstadoAsignacion.asignado).length;

  int get pendientes => asignaciones.length - asignados;

  Map<String, Object?> toJson() => {
        'id': id,
        'fecha': fechaATexto(fecha),
        'estado': estado.valor,
        'metodo': metodo,
        'aptitud': aptitud,
        'phi': phi,
        'phiValidador': phiValidador,
        'componentes': componentes.toJson(),
        'generaciones': generaciones,
        'tiempoMs': tiempoMs,
        'semilla': semilla,
        'creadoPor': creadoPor,
        'creadoEn': creadoEn.toIso8601String(),
        'aprobadoPor': aprobadoPor,
        'aprobadoEn': aprobadoEn?.toIso8601String(),
        'asignaciones': [for (final a in asignaciones) a.toJson()],
        'historial': [for (final p in historial) p.toJson()],
      };

  factory Programacion.fromJson(Map<String, Object?> json) => Programacion(
        id: json['id'] as int,
        fecha: textoAFecha(json['fecha'] as String),
        estado: EstadoProgramacion.desdeValor(json['estado'] as String),
        metodo: json['metodo'] as String,
        aptitud: (json['aptitud'] as num).toDouble(),
        phi: json['phi'] as int,
        phiValidador: json['phiValidador'] as int,
        componentes:
            ComponentesAptitud.fromJson((json['componentes'] as Map).cast<String, Object?>()),
        generaciones: json['generaciones'] as int,
        tiempoMs: json['tiempoMs'] as int,
        semilla: json['semilla'] as int?,
        creadoPor: json['creadoPor'] as String,
        creadoEn: DateTime.parse(json['creadoEn'] as String),
        aprobadoPor: json['aprobadoPor'] as String?,
        aprobadoEn: json['aprobadoEn'] == null ? null : DateTime.parse(json['aprobadoEn'] as String),
        asignaciones: [
          for (final a in (json['asignaciones'] as List? ?? const []))
            Asignacion.fromJson((a as Map).cast<String, Object?>()),
        ],
        historial: [
          for (final p in (json['historial'] as List? ?? const []))
            PuntoConvergencia.fromJson((p as Map).cast<String, Object?>()),
        ],
      );
}

/// Cuerpo de `POST /api/programaciones`.
class SolicitudProgramacion {
  const SolicitudProgramacion({required this.fecha});

  final DateTime fecha;

  Map<String, Object?> toJson() => {'fecha': fechaATexto(fecha)};

  factory SolicitudProgramacion.fromJson(Object? json) {
    final l = LectorJson(json);
    final solicitud = SolicitudProgramacion(fecha: l.fecha('fecha'));
    l.verificar();
    return solicitud;
  }
}

/// Cuerpo de `PUT /api/programaciones/{id}/asignaciones/{servicioId}`
/// (ajuste manual de HU-09).
class AjusteAsignacion {
  const AjusteAsignacion({
    required this.vehiculoId,
    required this.conductorId,
    required this.salida,
  });

  final int vehiculoId;
  final int conductorId;
  final int salida;

  Map<String, Object?> toJson() =>
      {'vehiculoId': vehiculoId, 'conductorId': conductorId, 'salida': salida};

  factory AjusteAsignacion.fromJson(Object? json) {
    final l = LectorJson(json);
    final ajuste = AjusteAsignacion(
      vehiculoId: l.entero('vehiculoId'),
      conductorId: l.entero('conductorId'),
      salida: l.entero('salida'),
    );
    l.verificar();
    return ajuste;
  }
}
