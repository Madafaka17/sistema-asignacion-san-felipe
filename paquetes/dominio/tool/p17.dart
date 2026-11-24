// Caso P-17 de la tesis (Tabla 87; RNF-02): el núcleo Dart genera la
// programación de un turno de 112 servicios con la configuración oficial del
// AG (Tabla 18) y 10 semillas, cada una en ≤ 300 s.
//
//   dart run tool/p17.dart [carpeta_salida]
//
// Escribe p17_tiempos.csv (una fila por semilla) y p17_resumen.txt en la
// carpeta de salida (por defecto, evidencia_p17/) y termina con código 1 si
// alguna ejecución supera los 300 s. La cobertura del núcleo (RNF-07), la otra
// mitad del caso, la mide herramientas/cobertura.sh. Los tiempos dependen del
// equipo: en la empresa debe repetirse en el servidor local (mini PC).
import 'dart:io';
import 'dart:math' as math;

import 'package:dominio/dominio.dart';

const servicios = 112;
const semillaInstancia = 101;
const semillasAG = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const limiteSegundos = 300.0;

/// Configuración oficial del algoritmo genético (Tabla 18), la misma de
/// tool/experimento.dart.
const parametrosOficiales = ParametrosAG(
  tamanoPoblacion: 50,
  generacionesMaximas: 100,
  probabilidadCruce: 0.80,
  probabilidadMutacion: 0.10,
  tamanoTorneo: 3,
  proporcionElite: 0.10,
  generacionesSinMejora: 100,
);

void main(List<String> argumentos) {
  final salida = Directory(argumentos.isEmpty ? 'evidencia_p17' : argumentos.first)..createSync(recursive: true);
  final instancia = GeneradorInstancias.generar(servicios: servicios, semilla: semillaInstancia);
  final validador = Validador(holguraMinima: instancia.holguraMinima);
  final limites = {
    for (final c in instancia.conductores.values) c.id: LimiteConduccion(c.acumulado, c.limite),
  };

  int phiValidado(List<int> cromosoma) => validador
      .validar([
        for (var i = 0; i < cromosoma.length; i++)
          () {
            final a = instancia.admisibles[i].alternativas[cromosoma[i]];
            return AsignacionValidable(
              servicioId: instancia.admisibles[i].servicioId,
              vehiculoId: a.vehiculoId,
              conductorId: a.conductorId,
              inicio: a.inicio,
              fin: a.fin,
            );
          }(),
      ], limites)
      .phi;

  final csv = StringBuffer('n,instancia,semilla,tiempo_s,aptitud,phi_validador\n');
  final tiempos = <double>[];
  var factibles = 0;
  for (final semilla in semillasAG) {
    final r = AlgoritmoGenetico(parametrosOficiales.conSemilla(semilla)).resolver(instancia);
    final t = r.tiempo.inMicroseconds / 1e6;
    final phi = phiValidado(r.cromosoma);
    tiempos.add(t);
    if (phi == 0) factibles++;
    csv.writeln('$servicios,$semillaInstancia,$semilla,${t.toStringAsFixed(6)},'
        '${r.evaluacion.aptitud.toStringAsFixed(6)},$phi');
    stdout.writeln('semilla $semilla: ${t.toStringAsFixed(3)} s, Φ = $phi');
  }
  final media = tiempos.reduce((a, b) => a + b) / tiempos.length;
  final de = math.sqrt(tiempos.map((t) => (t - media) * (t - media)).reduce((a, b) => a + b) / (tiempos.length - 1));
  final maximo = tiempos.reduce(math.max);
  final pasa = maximo <= limiteSegundos;
  final resumen = StringBuffer()
    ..writeln('P-17 (RNF-02): AG oficial, n = $servicios, instancia $semillaInstancia, semillas 1 a 10')
    ..writeln('Fecha (UTC): ${DateTime.now().toUtc().toIso8601String()}')
    ..writeln('Dart: ${Platform.version}')
    ..writeln('Equipo: ${Platform.numberOfProcessors} CPU lógicas; ${Platform.operatingSystemVersion}')
    ..writeln('Tiempo medio: ${media.toStringAsFixed(3)} s (DE ${de.toStringAsFixed(3)} s); '
        'máximo ${maximo.toStringAsFixed(3)} s; límite $limiteSegundos s')
    ..writeln('Programaciones factibles (Φ = 0 según el validador): $factibles de ${semillasAG.length}')
    ..writeln('Resultado: ${pasa ? 'APROBADO' : 'FALLIDO'} (todas las ejecuciones ≤ $limiteSegundos s)');
  File('${salida.path}/p17_tiempos.csv').writeAsStringSync(csv.toString());
  File('${salida.path}/p17_resumen.txt').writeAsStringSync(resumen.toString());
  stdout.write('\n$resumen');
  if (!pasa) exitCode = 1;
}
