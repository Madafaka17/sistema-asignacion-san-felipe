import '../contrato/lector_json.dart';

/// Ruta autorizada (HU-04). `duracionMin` es la duración estimada del
/// servicio; `vehiculosCompatibles` es la relación `κ(v, r)`.
class Ruta {
  const Ruta({
    this.id = 0,
    required this.codigo,
    required this.origen,
    required this.destino,
    required this.duracionMin,
    this.activa = true,
    this.vehiculosCompatibles = const [],
  });

  final int id;

  /// Código de la ruta, por ejemplo `R-03`.
  final String codigo;
  final String origen;
  final String destino;
  final int duracionMin;
  final bool activa;
  final List<int> vehiculosCompatibles;

  String get nombre => '$origen – $destino';

  Map<String, Object?> toJson() => {
        'id': id,
        'codigo': codigo,
        'origen': origen,
        'destino': destino,
        'duracionMin': duracionMin,
        'activa': activa,
        'vehiculosCompatibles': vehiculosCompatibles,
      };

  factory Ruta.fromJson(Object? json) {
    final l = LectorJson(json);
    final ruta = Ruta(
      id: l.enteroOpcional('id') ?? 0,
      codigo: l.texto('codigo', maximo: 10).toUpperCase(),
      origen: l.texto('origen', maximo: 80),
      destino: l.texto('destino', maximo: 80),
      duracionMin: l.entero('duracionMin'),
      activa: l.booleano('activa'),
      vehiculosCompatibles: l.listaEnteros('vehiculosCompatibles'),
    );
    l.verificar();
    return ruta;
  }
}

/// Hora de salida autorizada de una ruta (HU-05), elemento de `H_s`.
///
/// `duracionMin` permite registrar una duración distinta para esa salida
/// (por ejemplo, en hora punta); si es `null` se usa la de la ruta. Así la
/// duración `d_{s,h}` depende de la ruta y de la salida, como indica la tesis.
class SalidaAutorizada {
  const SalidaAutorizada({
    this.id = 0,
    required this.rutaId,
    required this.hora,
    this.duracionMin,
  });

  final int id;
  final int rutaId;

  /// Minutos desde la medianoche.
  final int hora;
  final int? duracionMin;

  Map<String, Object?> toJson() => {
        'id': id,
        'rutaId': rutaId,
        'hora': hora,
        'duracionMin': duracionMin,
      };

  factory SalidaAutorizada.fromJson(Object? json) {
    final l = LectorJson(json);
    final salida = SalidaAutorizada(
      id: l.enteroOpcional('id') ?? 0,
      rutaId: l.enteroOpcional('rutaId') ?? 0,
      hora: l.entero('hora'),
      duracionMin: l.enteroOpcional('duracionMin'),
    );
    l.verificar();
    return salida;
  }
}
