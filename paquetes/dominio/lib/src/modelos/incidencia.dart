import '../contrato/lector_json.dart';
import 'tiempo.dart';

/// Tipos de incidencia de HU-10. Las indisponibilidades son las
/// asignaciones inadecuadas que cuenta el indicador PIO (ecuación 19).
enum TipoIncidencia {
  retraso('retraso', 'Retraso'),
  reprogramacion('reprogramacion', 'Reprogramación'),
  indisponibilidadVehiculo('indisponibilidad_vehiculo', 'Indisponibilidad del vehículo'),
  indisponibilidadConductor('indisponibilidad_conductor', 'Indisponibilidad del conductor');

  const TipoIncidencia(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  /// Una indisponibilidad devuelve el servicio a `pendiente` para que se
  /// reprograme.
  bool get requiereReprogramar =>
      this == indisponibilidadVehiculo || this == indisponibilidadConductor;

  static TipoIncidencia desdeValor(String valor) =>
      TipoIncidencia.values.firstWhere((t) => t.valor == valor);
}

/// Incidencia registrada durante la operación (HU-10).
class Incidencia {
  const Incidencia({
    required this.id,
    required this.servicioId,
    required this.codigoServicio,
    required this.tipo,
    required this.fecha,
    required this.hora,
    this.minutosRetraso,
    required this.descripcion,
    this.vehiculoId,
    this.codigoVehiculo,
    this.conductorId,
    this.codigoConductor,
    this.registradoPor,
  });

  final int id;
  final int servicioId;
  final String codigoServicio;
  final TipoIncidencia tipo;
  final DateTime fecha;
  final int hora;
  final int? minutosRetraso;
  final String descripcion;

  /// Vehículo y conductor de la asignación aprobada del servicio.
  final int? vehiculoId;
  final String? codigoVehiculo;
  final int? conductorId;
  final String? codigoConductor;
  final String? registradoPor;

  Map<String, Object?> toJson() => {
        'id': id,
        'servicioId': servicioId,
        'codigoServicio': codigoServicio,
        'tipo': tipo.valor,
        'fecha': fechaATexto(fecha),
        'hora': hora,
        'minutosRetraso': minutosRetraso,
        'descripcion': descripcion,
        'vehiculoId': vehiculoId,
        'codigoVehiculo': codigoVehiculo,
        'conductorId': conductorId,
        'codigoConductor': codigoConductor,
        'registradoPor': registradoPor,
      };

  factory Incidencia.fromJson(Map<String, Object?> json) => Incidencia(
        id: json['id'] as int,
        servicioId: json['servicioId'] as int,
        codigoServicio: json['codigoServicio'] as String,
        tipo: TipoIncidencia.desdeValor(json['tipo'] as String),
        fecha: textoAFecha(json['fecha'] as String),
        hora: json['hora'] as int,
        minutosRetraso: json['minutosRetraso'] as int?,
        descripcion: json['descripcion'] as String,
        vehiculoId: json['vehiculoId'] as int?,
        codigoVehiculo: json['codigoVehiculo'] as String?,
        conductorId: json['conductorId'] as int?,
        codigoConductor: json['codigoConductor'] as String?,
        registradoPor: json['registradoPor'] as String?,
      );
}

/// Cuerpo de `POST /api/incidencias`. El servicio se identifica por su
/// código, como lo conoce el personal de despacho.
class SolicitudIncidencia {
  const SolicitudIncidencia({
    required this.codigoServicio,
    required this.tipo,
    required this.fecha,
    required this.hora,
    this.minutosRetraso,
    required this.descripcion,
  });

  final String codigoServicio;
  final TipoIncidencia tipo;
  final DateTime fecha;
  final int hora;
  final int? minutosRetraso;
  final String descripcion;

  Map<String, Object?> toJson() => {
        'codigoServicio': codigoServicio,
        'tipo': tipo.valor,
        'fecha': fechaATexto(fecha),
        'hora': hora,
        if (minutosRetraso != null) 'minutosRetraso': minutosRetraso,
        'descripcion': descripcion,
      };

  factory SolicitudIncidencia.fromJson(Object? json) {
    final l = LectorJson(json);
    final solicitud = SolicitudIncidencia(
      codigoServicio: l.texto('codigoServicio', maximo: 12).toUpperCase(),
      tipo: l.enumeracion('tipo', TipoIncidencia.values, (t) => t.valor),
      fecha: l.fecha('fecha'),
      hora: l.entero('hora'),
      minutosRetraso: l.enteroOpcional('minutosRetraso'),
      descripcion: l.texto('descripcion', maximo: 500),
    );
    l.verificar();
    return solicitud;
  }
}
