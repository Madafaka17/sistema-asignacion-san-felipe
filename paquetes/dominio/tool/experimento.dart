// Reproduce el protocolo de las pruebas de concepto de la tesis (Tablas 17
// y 18) con la implementación en Dart del núcleo de optimización.
//
//   dart run tool/experimento.dart [carpeta_salida]
//
// Escribe resultados_crudos.csv (una fila por ejecución) y resumen.csv
// (medias por método y tamaño). Mismas instancias, semillas y métricas en
// cada corrida: los resultados son reproducibles, salvo los tiempos.
import 'dart:io';
import 'dart:math' as math;

import 'package:dominio/dominio.dart';

const tamanos = [7, 14, 28, 56, 112];
const semillasInstancia = [101, 102, 103];
const semillasAG = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

/// Configuración oficial del algoritmo genético (Tabla 18).
const parametrosOficiales = ParametrosAG(
  tamanoPoblacion: 50,
  generacionesMaximas: 100,
  probabilidadCruce: 0.80,
  probabilidadMutacion: 0.10,
  tamanoTorneo: 3,
  proporcionElite: 0.10,
  generacionesSinMejora: 100,
);

class Ejecucion {
  Ejecucion(this.metodo, this.n, this.instancia, this.semilla, this.tiempoS, this.aptitud, this.phi);
  final String metodo;
  final int n;
  final int instancia;
  final int? semilla;
  final double tiempoS;
  final double aptitud;
  final int phi;
}

void main(List<String> argumentos) {
  final salida = Directory(argumentos.isEmpty ? 'resultados_experimento' : argumentos.first)
    ..createSync(recursive: true);
  final ejecuciones = <Ejecucion>[];
  final referencias = <(int, int), double>{};

  for (final n in tamanos) {
    for (final semillaInstancia in semillasInstancia) {
      final instancia = GeneradorInstancias.generar(servicios: n, semilla: semillaInstancia);
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

      final voraz = const AlgoritmoVoraz().resolver(instancia);
      ejecuciones.add(Ejecucion('voraz', n, semillaInstancia, null, voraz.tiempo.inMicroseconds / 1e6,
          voraz.evaluacion.aptitud, phiValidado(voraz.cromosoma)));

      for (final semilla in semillasAG) {
        final ag = AlgoritmoGenetico(parametrosOficiales.conSemilla(semilla)).resolver(instancia);
        ejecuciones.add(Ejecucion('algoritmo_genetico', n, semillaInstancia, semilla,
            ag.tiempo.inMicroseconds / 1e6, ag.evaluacion.aptitud, phiValidado(ag.cromosoma)));
      }

      // Referencia: óptimo por enumeración en n = 7; mejor solución conocida
      // entre todas las ejecuciones en n ≥ 14.
      var referencia = ejecuciones
          .where((e) => e.n == n && e.instancia == semillaInstancia)
          .map((e) => e.aptitud)
          .reduce(math.max);
      if (n == 7) referencia = _optimoExhaustivo(instancia);
      referencias[(n, semillaInstancia)] = referencia;
      stdout.writeln('n=$n instancia=$semillaInstancia referencia=${referencia.toStringAsFixed(4)}');
    }
  }

  double brecha(Ejecucion e) {
    final ref = referencias[(e.n, e.instancia)]!;
    return math.min(100, math.max(0, (ref - e.aptitud) / ref.abs() * 100));
  }

  final crudos = StringBuffer('metodo,n,instancia,semilla,tiempo_s,aptitud,phi_validador,brecha_pct\n');
  for (final e in ejecuciones) {
    crudos.writeln('${e.metodo},${e.n},${e.instancia},${e.semilla ?? ''},${e.tiempoS.toStringAsFixed(6)},'
        '${e.aptitud.toStringAsFixed(6)},${e.phi},${brecha(e).toStringAsFixed(4)}');
  }
  File('${salida.path}/resultados_crudos.csv').writeAsStringSync(crudos.toString());

  final resumen = StringBuffer('metodo,n,ejecuciones,tiempo_medio_s,brecha_media_pct,phi_medio\n');
  for (final metodo in ['voraz', 'algoritmo_genetico']) {
    for (final n in tamanos) {
      final grupo = ejecuciones.where((e) => e.metodo == metodo && e.n == n).toList();
      double media(double Function(Ejecucion) f) => grupo.map(f).reduce((a, b) => a + b) / grupo.length;
      resumen.writeln('$metodo,$n,${grupo.length},${media((e) => e.tiempoS).toStringAsFixed(4)},'
          '${media(brecha).toStringAsFixed(2)},${media((e) => e.phi.toDouble()).toStringAsFixed(2)}');
    }
  }
  File('${salida.path}/resumen.csv').writeAsStringSync(resumen.toString());
  stdout
    ..writeln()
    ..write(resumen);
}

double _optimoExhaustivo(InstanciaTurno instancia) {
  final evaluador = Evaluador(instancia);
  final tamanos = [for (final s in instancia.admisibles) s.alternativas.length];
  final actual = List.filled(tamanos.length, 0);
  var mejor = evaluador.evaluar(actual).aptitud;
  while (true) {
    var i = 0;
    while (i < actual.length && ++actual[i] == tamanos[i]) {
      actual[i] = 0;
      i++;
    }
    if (i == actual.length) return mejor;
    mejor = math.max(mejor, evaluador.evaluar(actual).aptitud);
  }
}
