import '../contrato/lector_json.dart';
import 'tiempo.dart';

/// Entrada de una unidad en la cola de despacho de una ruta para una fecha
/// (sección 3.1.2 de la tesis). Las unidades salen por orden de llegada:
/// `posicion` es `π`, la posición en la cola de su destino (1 = primera).
///
/// Las entradas no se borran ni se reordenan: cada llegada recibe la
/// posición siguiente a la última registrada y, si la unidad deja la cola,
/// la entrada queda inactiva. Así se conserva el orden en que se formó.
class EntradaCola {
  const EntradaCola({
    this.id = 0,
    required this.rutaId,
    required this.fecha,
    required this.vehiculoId,
    required this.posicion,
    required this.llegada,
    this.activa = true,
    this.codigoVehiculo,
    this.servicioId,
    this.codigoServicio,
  });

  final int id;
  final int rutaId;
  final DateTime fecha;
  final int vehiculoId;

  /// `π`, 1 = primera.
  final int posicion;

  /// Hora de llegada al terminal, en minutos desde la medianoche.
  final int llegada;

  /// `false` si la unidad se retiró de la cola.
  final bool activa;

  /// Solo informativo en las respuestas.
  final String? codigoVehiculo;

  /// Servicio no cancelado para el que esta entrada define `v0(s)`.
  final int? servicioId;
  final String? codigoServicio;

  /// Puede asociarse a un servicio nuevo.
  bool get libre => activa && servicioId == null;

  Map<String, Object?> toJson() => {
        'id': id,
        'rutaId': rutaId,
        'fecha': fechaATexto(fecha),
        'vehiculoId': vehiculoId,
        'posicion': posicion,
        'llegada': llegada,
        'activa': activa,
        if (codigoVehiculo != null) 'codigoVehiculo': codigoVehiculo,
        'servicioId': servicioId,
        if (codigoServicio != null) 'codigoServicio': codigoServicio,
      };

  factory EntradaCola.fromJson(Object? json) {
    final l = LectorJson(json);
    final entrada = EntradaCola(
      id: l.entero('id'),
      rutaId: l.entero('rutaId'),
      fecha: l.fecha('fecha'),
      vehiculoId: l.entero('vehiculoId'),
      posicion: l.entero('posicion'),
      llegada: l.entero('llegada'),
      activa: l.booleano('activa'),
      codigoVehiculo: l.textoOpcional('codigoVehiculo'),
      servicioId: l.enteroOpcional('servicioId'),
      codigoServicio: l.textoOpcional('codigoServicio'),
    );
    l.verificar();
    return entrada;
  }
}

/// Cuerpo de `POST /api/cola`: llegada de una unidad al terminal.
class SolicitudEntradaCola {
  const SolicitudEntradaCola({
    required this.rutaId,
    required this.fecha,
    required this.vehiculoId,
    required this.llegada,
  });

  final int rutaId;
  final DateTime fecha;
  final int vehiculoId;
  final int llegada;

  Map<String, Object?> toJson() => {
        'rutaId': rutaId,
        'fecha': fechaATexto(fecha),
        'vehiculoId': vehiculoId,
        'llegada': llegada,
      };

  factory SolicitudEntradaCola.fromJson(Object? json) {
    final l = LectorJson(json);
    final solicitud = SolicitudEntradaCola(
      rutaId: l.entero('rutaId'),
      fecha: l.fecha('fecha'),
      vehiculoId: l.entero('vehiculoId'),
      llegada: l.entero('llegada'),
    );
    l.verificar();
    return solicitud;
  }
}
