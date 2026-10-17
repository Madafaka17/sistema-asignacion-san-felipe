import 'dart:convert';
import 'dart:io';

import 'package:dominio/dominio.dart';
import 'package:servidor/servidor.dart';
import 'package:test/test.dart';

/// RNF-07: el método, sus parámetros y los pesos se leen del archivo de
/// configuración y se validan al iniciar.
void main() {
  test('config/parametros.yaml es válido y reproduce la Tabla 23 de la tesis', () {
    final p = ParametrosSistema.desdeArchivo('../config/parametros.yaml');
    expect(p.metodo, AlgoritmoGenetico.identificador);
    final ag = p.algoritmoGenetico;
    expect([ag.tamanoPoblacion, ag.generacionesMaximas, ag.tamanoTorneo, ag.generacionesSinMejora], [50, 100, 3, 20]);
    expect([ag.probabilidadCruce, ag.probabilidadMutacion, ag.proporcionElite], [0.80, 0.10, 0.10]);
    expect(ag.limiteTiempo, const Duration(seconds: 300));
    expect(p.modelo.holguraMinima, 10);
    expect(p.modelo.pesos.suma, closeTo(1, 1e-12));
    expect(p.intentosMaximos, 5);
    expect(p.minutosBloqueo, 15);
  });

  test('los parámetros efectivos se pueden volver a leer sin cambios', () {
    final p = ParametrosSistema.desdeArchivo('../config/parametros.yaml');
    final copia = ParametrosSistema.desdeYaml(jsonEncode(p.toJson())); // JSON es YAML válido
    expect(copia.toJson(), p.toJson());
  });

  test('un archivo inválido detiene el inicio con la lista de errores', () {
    final texto = File('../config/parametros.yaml').readAsStringSync().replaceFirst('retraso: 0.25', 'retraso: 0.5');
    expect(
      () => ParametrosSistema.desdeYaml(texto),
      throwsA(isA<FormatException>().having((e) => e.message, 'mensaje', contains('La suma de los pesos w_j debe ser 1'))),
    );
    expect(
      () => ParametrosSistema.desdeYaml('optimizacion:\n  metodo: tabu\n'),
      throwsA(isA<FormatException>().having((e) => e.message, 'mensaje', contains('optimizacion.metodo'))),
    );
  });
}
