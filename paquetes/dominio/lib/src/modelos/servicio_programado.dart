import '../contrato/lector_json.dart';
import 'tiempo.dart';

enum EstadoServicio {
  /// Registrado o afectado por una indisponibilidad: debe programarse.
  pendiente('pendiente', 'Pendiente'),

  /// Cubierto por la programación aprobada de su fecha.
  programado('programado', 'Programado'),
  cancelado('cancelado', 'Cancelado');

  const EstadoServicio(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoServicio desdeValor(String valor) =>
      EstadoServicio.values.firstWhere((e) => e.valor == valor);
}

/// Servicio programado del turno (HU-06), elemento `s ∈ S`.
///
/// * `rutaId` es `r(s)`, atributo del servicio y no una decisión.
/// * `horaSolicitada` es una salida autorizada de la ruta; las salidas
///   candidatas `H_s` son las autorizadas entre esa hora y la tolerancia
///   configurada.
/// * `prioridad` es `p_s` (3 = más alta) y `capacidadRequerida` es `q_s`.
class ServicioProgramado {
  const ServicioProgramado({
    this.id = 0,
    required this.codigo,
    required this.fecha,
    required this.rutaId,
    required this.horaSolicitada,
    required this.prioridad,
    required this.capacidadRequerida,
    this.estado = EstadoServicio.pendiente,
    this.codigoRuta,
  });

  final int id;

  /// Código del servicio, por ejemplo `S-115`.
  final String codigo;
  final DateTime fecha;
  final int rutaId;
  final int horaSolicitada;
  final int prioridad;
  final int capacidadRequerida;
  final EstadoServicio estado;

  /// Solo informativo en las respuestas.
  final String? codigoRuta;

  Map<String, Object?> toJson() => {
        'id': id,
        'codigo': codigo,
        'fecha': fechaATexto(fecha),
        'rutaId': rutaId,
        'horaSolicitada': horaSolicitada,
        'prioridad': prioridad,
        'capacidadRequerida': capacidadRequerida,
        'estado': estado.valor,
        if (codigoRuta != null) 'codigoRuta': codigoRuta,
      };

  /// Cuerpo de alta o edición: sin `id`, `estado` ni `codigoRuta`.
  Map<String, Object?> toJsonSolicitud() => {
        'codigo': codigo,
        'fecha': fechaATexto(fecha),
        'rutaId': rutaId,
        'horaSolicitada': horaSolicitada,
        'prioridad': prioridad,
        'capacidadRequerida': capacidadRequerida,
      };

  factory ServicioProgramado.fromJson(Object? json) {
    final l = LectorJson(json);
    final servicio = ServicioProgramado(
      id: l.enteroOpcional('id') ?? 0,
      codigo: l.texto('codigo', maximo: 12).toUpperCase(),
      fecha: l.fecha('fecha'),
      rutaId: l.entero('rutaId'),
      horaSolicitada: l.entero('horaSolicitada'),
      prioridad: l.entero('prioridad'),
      capacidadRequerida: l.entero('capacidadRequerida'),
      estado: l.contiene('estado')
          ? l.enumeracion('estado', EstadoServicio.values, (e) => e.valor)
          : EstadoServicio.pendiente,
      codigoRuta: l.textoOpcional('codigoRuta'),
    );
    l.verificar();
    return servicio;
  }
}
