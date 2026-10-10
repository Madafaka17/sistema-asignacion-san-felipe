import '../contrato/lector_json.dart';
import 'tiempo.dart';

/// Categorías de licencia de conducir para transporte de pasajeros.
/// La relación con las categorías vehiculares que habilita cada una se
/// configura en `config/parametros.yaml` (`habilitacion_licencias`).
enum CategoriaLicencia {
  aIIa('A-IIa'),
  aIIb('A-IIb'),
  aIIIa('A-IIIa'),
  aIIIb('A-IIIb'),
  aIIIc('A-IIIc');

  const CategoriaLicencia(this.valor);

  final String valor;

  static CategoriaLicencia desdeValor(String valor) =>
      CategoriaLicencia.values.firstWhere((c) => c.valor == valor);
}

/// Conductor (HU-03).
///
/// * `turnoInicio`–`turnoFin` es el turno `T_c`, en minutos del día.
/// * `minutosAcumulados` es `H_c0`, la conducción ya acumulada en el periodo
///   de control.
/// * `limiteMinutos` es `H_cmáx`.
/// * `disponible` lo marca el despacho; junto con la licencia vigente define
///   `E_c` en la ecuación (1).
class Conductor {
  const Conductor({
    this.id = 0,
    required this.codigo,
    required this.dni,
    required this.nombres,
    required this.apellidos,
    required this.categoriaLicencia,
    required this.vencimientoLicencia,
    required this.turnoInicio,
    required this.turnoFin,
    this.minutosAcumulados = 0,
    required this.limiteMinutos,
    this.disponible = true,
  });

  final int id;

  /// Código interno, por ejemplo `C-12`.
  final String codigo;
  final String dni;
  final String nombres;
  final String apellidos;
  final CategoriaLicencia categoriaLicencia;
  final DateTime vencimientoLicencia;
  final int turnoInicio;
  final int turnoFin;
  final int minutosAcumulados;
  final int limiteMinutos;
  final bool disponible;

  String get nombreCompleto => '$nombres $apellidos';

  /// La licencia sigue vigente durante todo el día [fecha].
  bool licenciaVigente(DateTime fecha) => !soloFecha(vencimientoLicencia).isBefore(soloFecha(fecha));

  static final formatoDni = RegExp(r'^[0-9]{8}$');

  Conductor copiarCon({int? id, bool? disponible, int? minutosAcumulados}) => Conductor(
        id: id ?? this.id,
        codigo: codigo,
        dni: dni,
        nombres: nombres,
        apellidos: apellidos,
        categoriaLicencia: categoriaLicencia,
        vencimientoLicencia: vencimientoLicencia,
        turnoInicio: turnoInicio,
        turnoFin: turnoFin,
        minutosAcumulados: minutosAcumulados ?? this.minutosAcumulados,
        limiteMinutos: limiteMinutos,
        disponible: disponible ?? this.disponible,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'codigo': codigo,
        'dni': dni,
        'nombres': nombres,
        'apellidos': apellidos,
        'categoriaLicencia': categoriaLicencia.valor,
        'vencimientoLicencia': fechaATexto(vencimientoLicencia),
        'turnoInicio': turnoInicio,
        'turnoFin': turnoFin,
        'minutosAcumulados': minutosAcumulados,
        'limiteMinutos': limiteMinutos,
        'disponible': disponible,
      };

  factory Conductor.fromJson(Object? json) {
    final l = LectorJson(json);
    final conductor = Conductor(
      id: l.enteroOpcional('id') ?? 0,
      codigo: l.texto('codigo', maximo: 10).toUpperCase(),
      dni: l.texto('dni', maximo: 8),
      nombres: l.texto('nombres', maximo: 60),
      apellidos: l.texto('apellidos', maximo: 80),
      categoriaLicencia:
          l.enumeracion('categoriaLicencia', CategoriaLicencia.values, (c) => c.valor),
      vencimientoLicencia: l.fecha('vencimientoLicencia'),
      turnoInicio: l.entero('turnoInicio'),
      turnoFin: l.entero('turnoFin'),
      minutosAcumulados: l.entero('minutosAcumulados'),
      limiteMinutos: l.entero('limiteMinutos'),
      disponible: l.booleano('disponible'),
    );
    l.verificar();
    return conductor;
  }
}
