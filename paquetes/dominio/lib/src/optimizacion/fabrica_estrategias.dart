import 'algoritmo_genetico.dart';
import 'algoritmo_voraz.dart';
import 'estrategia.dart';
import 'parametros.dart';

/// Patrón Factory: crea la estrategia configurada en `config/parametros.yaml`
/// (`metodo`) sin que la lógica de negocio conozca las clases concretas.
class FabricaEstrategias {
  const FabricaEstrategias._();

  static const metodosDisponibles = [AlgoritmoGenetico.identificador, AlgoritmoVoraz.identificador];

  static EstrategiaOptimizacion crear(String metodo, {ParametrosAG parametrosAG = const ParametrosAG()}) =>
      switch (metodo) {
        AlgoritmoGenetico.identificador => AlgoritmoGenetico(parametrosAG),
        AlgoritmoVoraz.identificador => const AlgoritmoVoraz(),
        _ => throw ArgumentError.value(
            metodo,
            'metodo',
            'Método no disponible; opciones: ${metodosDisponibles.join(', ')}',
          ),
      };
}
