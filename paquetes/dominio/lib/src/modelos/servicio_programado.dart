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
/// * `entradaColaId` es el turno en la cola de su destino: la unidad de esa
///   entrada es `v0(s)` y su posición, `π(s)`. La hora solicitada es la
///   salida nominal, desde la que se mide la demora `Δt(s)`. Un servicio sin
///   entrada no está sujeto a la regla de cola.
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
    this.entradaColaId,
    this.codigoRuta,
    this.codigoVehiculoCola,
    this.posicionCola,
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
  final int? entradaColaId;

  /// Solo informativos en las respuestas.
  final String? codigoRuta;
  final String? codigoVehiculoCola;
  final int? posicionCola;

  Map<String, Object?> toJson() => {
        'id': id,
        'codigo': codigo,
        'fecha': fechaATexto(fecha),
        'rutaId': rutaId,
        'horaSolicitada': horaSolicitada,
        'prioridad': prioridad,
        'capacidadRequerida': capacidadRequerida,
        'estado': estado.valor,
        'entradaColaId': entradaColaId,
        if (codigoRuta != null) 'codigoRuta': codigoRuta,
        if (codigoVehiculoCola != null) 'codigoVehiculoCola': codigoVehiculoCola,
        if (posicionCola != null) 'posicionCola': posicionCola,
      };

  /// Cuerpo de alta o edición: sin `id`, `estado` ni los campos informativos.
  Map<String, Object?> toJsonSolicitud() => {
        'codigo': codigo,
        'fecha': fechaATexto(fecha),
        'rutaId': rutaId,
        'horaSolicitada': horaSolicitada,
        'prioridad': prioridad,
        'capacidadRequerida': capacidadRequerida,
        'entradaColaId': entradaColaId,
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
      entradaColaId: l.enteroOpcional('entradaColaId'),
      codigoRuta: l.textoOpcional('codigoRuta'),
      codigoVehiculoCola: l.textoOpcional('codigoVehiculoCola'),
      posicionCola: l.enteroOpcional('posicionCola'),
    );
    l.verificar();
    return servicio;
  }
}
