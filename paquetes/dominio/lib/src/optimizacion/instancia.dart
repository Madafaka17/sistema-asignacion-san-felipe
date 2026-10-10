/// Estructuras de datos de la instancia del turno (Tabla 11 de la tesis).
///
/// La capa de lógica de negocio construye la instancia con
/// `ConstructorInstancia` y la entrega al módulo de optimización, que no
/// accede a la base de datos ni a la interfaz.
library;

/// Alternativa admisible `a = (v, c, h) ∈ A_s` de la ecuación (1).
class Alternativa {
  const Alternativa({
    required this.vehiculoId,
    required this.conductorId,
    required this.salida,
    required this.duracion,
  });

  /// `v(a)`.
  final int vehiculoId;

  /// `c(a)`.
  final int conductorId;

  /// `h(a)`: hora de salida, que es también la hora de inicio `t_{s,a}`.
  final int salida;

  /// `d_{s,a}`, en minutos.
  final int duracion;

  int get inicio => salida;

  int get fin => salida + duracion;

  bool mismaQue(Alternativa? otra) =>
      otra != null &&
      otra.vehiculoId == vehiculoId &&
      otra.conductorId == conductorId &&
      otra.salida == salida;

  @override
  String toString() => '(v$vehiculoId, c$conductorId, $salida+$duracion)';
}

/// Servicio `s ∈ S` con su conjunto de alternativas admisibles `A_s`.
class ServicioTurno {
  ServicioTurno({
    required this.servicioId,
    required this.codigo,
    required this.codigoRuta,
    required this.prioridad,
    required this.capacidadRequerida,
    required List<Alternativa> alternativas,
    this.comprometida,
    this.motivoSinAlternativas,
  }) : alternativas = List.unmodifiable(alternativas);

  final int servicioId;
  final String codigo;
  final String codigoRuta;

  /// `p_s`, de 1 a 3 (3 = más alta).
  final int prioridad;

  /// `q_s`.
  final int capacidadRequerida;

  /// `A_s`, ordenado por hora de salida y luego por vehículo y conductor.
  /// El gen `α_s` es un índice de esta lista (ecuación 15).
  final List<Alternativa> alternativas;

  /// `b(s)`: alternativa de la programación aprobada vigente, si existe.
  /// Puede no pertenecer a `A_s` (por ejemplo, si su vehículo entró a
  /// mantenimiento después de aprobarse).
  final Alternativa? comprometida;

  /// Explicación para el operador cuando `A_s = ∅`.
  final String? motivoSinAlternativas;

  /// `s ∈ S'`.
  bool get tieneAlternativas => alternativas.isNotEmpty;
}

/// Conductor con su conducción acumulada `H_c0` y su límite `H_cmáx`.
class ConductorTurno {
  const ConductorTurno({
    required this.id,
    required this.codigo,
    required this.acumulado,
    required this.limite,
  });

  final int id;
  final String codigo;
  final int acumulado;
  final int limite;
}

/// Pesos `w_j` de los criterios blandos de `J(X)` (ecuación 8).
class PesosPerdida {
  const PesosPerdida({
    this.retraso = 0.25,
    this.reprogramacion = 0.25,
    this.tiempoMuerto = 0.25,
    this.desequilibrio = 0.25,
  });

  final double retraso;
  final double reprogramacion;
  final double tiempoMuerto;
  final double desequilibrio;

  double get suma => retraso + reprogramacion + tiempoMuerto + desequilibrio;
}

/// Referencias de normalización `b_j > 0` de `J(X)` (ecuación 8).
class ReferenciasPerdida {
  const ReferenciasPerdida({
    required this.retraso,
    required this.reprogramacion,
    required this.tiempoMuerto,
    required this.desequilibrio,
  });

  final double retraso;
  final double reprogramacion;
  final double tiempoMuerto;
  final double desequilibrio;
}

/// Instancia validada del turno que recibe el módulo de optimización.
class InstanciaTurno {
  InstanciaTurno({
    required this.fecha,
    required List<ServicioTurno> servicios,
    required Map<int, ConductorTurno> conductores,
    required Map<int, String> codigosVehiculo,
    required this.holguraMinima,
    required this.pesos,
    required this.referencias,
    this.penalizacion = 1e6,
  })  : servicios = List.unmodifiable(servicios),
        admisibles = List.unmodifiable(servicios.where((s) => s.tieneAlternativas)),
        conductores = Map.unmodifiable(conductores),
        codigosVehiculo = Map.unmodifiable(codigosVehiculo);

  final DateTime fecha;

  /// `S`: todos los servicios del turno.
  final List<ServicioTurno> servicios;

  /// `S' = {s ∈ S : A_s ≠ ∅}`, en el orden de los genes del cromosoma.
  final List<ServicioTurno> admisibles;

  /// `C` con `H_c0` y `H_cmáx`.
  final Map<int, ConductorTurno> conductores;

  /// Códigos de los vehículos disponibles, para los mensajes.
  final Map<int, String> codigosVehiculo;

  /// `t_mín`: holgura mínima entre servicios del mismo vehículo o conductor.
  final int holguraMinima;
  final PesosPerdida pesos;
  final ReferenciasPerdida referencias;

  /// `M`: penalización estática de las restricciones duras.
  final double penalizacion;

  /// `n = |S'|`, longitud del cromosoma.
  int get n => admisibles.length;

  /// `K = Σ |A_s|`.
  int get totalAlternativas => admisibles.fold(0, (suma, s) => suma + s.alternativas.length);

  /// Tamaño del espacio de búsqueda `Π |A_s|` (puede ser muy grande).
  double get tamanoEspacio =>
      admisibles.fold(1.0, (producto, s) => producto * s.alternativas.length);
}
