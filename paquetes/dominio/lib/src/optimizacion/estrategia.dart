import '../modelos/programacion.dart';
import 'evaluador.dart';
import 'instancia.dart';

/// Versión del núcleo de optimización. Se guarda con cada ejecución junto
/// con el método, la semilla, los parámetros y la huella de la entrada, para
/// identificar con qué código se obtuvo una propuesta.
const versionNucleo = '1.2.0';

/// Resultado de una estrategia de optimización.
class ResultadoOptimizacion {
  const ResultadoOptimizacion({
    required this.metodo,
    required this.cromosoma,
    required this.evaluacion,
    required this.generaciones,
    required this.historial,
    required this.tiempo,
    this.semilla,
  });

  /// Identificador de la estrategia (por ejemplo `algoritmo_genetico`).
  final String metodo;

  /// Mejor cromosoma `α*`: un índice de `A_s` por cada servicio de `S'`.
  final List<int> cromosoma;

  /// `F(α*)` y sus componentes.
  final Evaluacion evaluacion;
  final int generaciones;
  final List<PuntoConvergencia> historial;
  /// Tiempo del núcleo, medido dentro de la estrategia: no incluye la
  /// lectura de datos, la construcción de `A_s` ni la API.
  final Duration tiempo;
  final int? semilla;

  /// `método@versión del núcleo`, por ejemplo `algoritmo_genetico@1.2.0`.
  String get versionAlgoritmo => '$metodo@$versionNucleo';
}

/// Patrón Strategy: todas las estrategias reciben la misma instancia, se
/// evalúan con la misma `F(X)` y devuelven el mismo tipo de resultado, de
/// modo que el método de la sección 3.3 puede cambiarse sin modificar las
/// demás capas.
abstract interface class EstrategiaOptimizacion {
  String get id;

  ResultadoOptimizacion resolver(InstanciaTurno instancia);
}
