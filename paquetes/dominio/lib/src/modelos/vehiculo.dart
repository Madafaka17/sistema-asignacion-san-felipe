import '../contrato/lector_json.dart';

/// Categoría vehicular del Reglamento Nacional de Vehículos
/// (D.S. N.° 058-2003-MTC): M1, hasta 8 asientos más el conductor; M2 y M3,
/// más de 8 asientos (M3 con más de 5 t).
enum CategoriaVehiculo {
  m1('M1'),
  m2('M2'),
  m3('M3');

  const CategoriaVehiculo(this.valor);

  final String valor;

  static CategoriaVehiculo desdeValor(String valor) =>
      CategoriaVehiculo.values.firstWhere((c) => c.valor == valor);
}

/// Estado de la unidad. Solo una unidad `operativo` tiene `E_v = 1`.
enum EstadoVehiculo {
  operativo('operativo', 'Operativo'),
  mantenimiento('mantenimiento', 'En mantenimiento'),
  inactivo('inactivo', 'Inactivo');

  const EstadoVehiculo(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoVehiculo desdeValor(String valor) =>
      EstadoVehiculo.values.firstWhere((e) => e.valor == valor);
}

/// Unidad vehicular (HU-02). `capacidad` es `Q_v` en el modelo.
class Vehiculo {
  const Vehiculo({
    this.id = 0,
    required this.codigo,
    required this.placa,
    required this.capacidad,
    required this.categoria,
    this.estado = EstadoVehiculo.operativo,
  });

  final int id;

  /// Código interno de la unidad, por ejemplo `V-07`.
  final String codigo;

  /// Placa de rodaje, formato `ABC-123`.
  final String placa;
  final int capacidad;
  final CategoriaVehiculo categoria;
  final EstadoVehiculo estado;

  /// `E_v` de la ecuación (1).
  bool get disponible => estado == EstadoVehiculo.operativo;

  static final formatoPlaca = RegExp(r'^[A-Z0-9]{3}-[0-9]{3}$');

  Vehiculo copiarCon({int? id, EstadoVehiculo? estado}) => Vehiculo(
        id: id ?? this.id,
        codigo: codigo,
        placa: placa,
        capacidad: capacidad,
        categoria: categoria,
        estado: estado ?? this.estado,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'codigo': codigo,
        'placa': placa,
        'capacidad': capacidad,
        'categoria': categoria.valor,
        'estado': estado.valor,
      };

  factory Vehiculo.fromJson(Object? json) {
    final l = LectorJson(json);
    final vehiculo = Vehiculo(
      id: l.enteroOpcional('id') ?? 0,
      codigo: l.texto('codigo', maximo: 10).toUpperCase(),
      placa: l.texto('placa', maximo: 7).toUpperCase(),
      capacidad: l.entero('capacidad'),
      categoria: l.enumeracion('categoria', CategoriaVehiculo.values, (c) => c.valor),
      estado: l.enumeracion('estado', EstadoVehiculo.values, (e) => e.valor),
    );
    l.verificar();
    return vehiculo;
  }
}
