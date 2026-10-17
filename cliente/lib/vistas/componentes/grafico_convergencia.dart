import 'dart:math' as math;

import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';

/// Curva de convergencia del algoritmo genético: mejor aptitud y aptitud
/// promedio de la población en cada generación (Tabla 22, paso 8).
class GraficoConvergencia extends StatelessWidget {
  const GraficoConvergencia({super.key, required this.historial, this.alto = 220});

  final List<PuntoConvergencia> historial;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    if (historial.length < 2) {
      return SizedBox(height: alto, child: const Center(child: Text('Sin curva de convergencia para este método')));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Curva de convergencia de ${historial.length} generaciones; '
              'mejor aptitud final ${historial.last.mejor.toStringAsFixed(4)}',
          child: SizedBox(
            height: alto,
            width: double.infinity,
            child: CustomPaint(
              painter: _PintorConvergencia(
                historial,
                mejor: esquema.primary,
                promedio: esquema.tertiary,
                ejes: esquema.outline,
                texto: Theme.of(context).textTheme.bodySmall!,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 16, children: [
          _Leyenda(color: esquema.primary, texto: 'Mejor F(X)'),
          _Leyenda(color: esquema.tertiary, texto: 'F(X) promedio'),
        ]),
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 16, height: 3, color: color),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _PintorConvergencia extends CustomPainter {
  _PintorConvergencia(this.historial, {required this.mejor, required this.promedio, required this.ejes, required this.texto});

  final List<PuntoConvergencia> historial;
  final Color mejor;
  final Color promedio;
  final Color ejes;
  final TextStyle texto;

  static const _margenIzquierdo = 64.0;
  static const _margenInferior = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTRB(_margenIzquierdo, 8, size.width - 8, size.height - _margenInferior);
    final valores = [for (final p in historial) ...[p.mejor, p.promedio]];
    // Las aptitudes de soluciones infactibles (−M·Φ) aplastan la escala: el
    // eje se ajusta a la mejor curva y se recorta el promedio.
    final maximo = valores.reduce(math.max);
    var minimo = historial.map((p) => p.mejor).reduce(math.min);
    if (maximo - minimo < 1e-9) minimo = maximo - 1;
    final rango = maximo - minimo;
    final ultimaGeneracion = math.max(1, historial.last.generacion);

    Offset punto(int generacion, double valor) => Offset(
          area.left + area.width * generacion / ultimaGeneracion,
          area.bottom - area.height * ((valor.clamp(minimo, maximo) - minimo) / rango),
        );

    final pincelEjes = Paint()
      ..color = ejes
      ..strokeWidth = 1;
    canvas
      ..drawLine(area.bottomLeft, area.bottomRight, pincelEjes)
      ..drawLine(area.bottomLeft, area.topLeft, pincelEjes);

    void rotulo(String t, Offset posicion, {bool derecha = false}) {
      final p = TextPainter(text: TextSpan(text: t, style: texto), textDirection: TextDirection.ltr)..layout();
      p.paint(canvas, derecha ? posicion - Offset(p.width, p.height / 2) : posicion);
    }

    rotulo(maximo.toStringAsFixed(3), Offset(area.left - 4, area.top), derecha: true);
    rotulo(minimo.toStringAsFixed(3), Offset(area.left - 4, area.bottom), derecha: true);
    rotulo('0', Offset(area.left, area.bottom + 4));
    rotulo('Generación $ultimaGeneracion', Offset(area.right - 90, area.bottom + 4));

    void curva(double Function(PuntoConvergencia) valor, Color color) {
      final trazo = Path();
      for (final (i, p) in historial.indexed) {
        final o = punto(p.generacion, valor(p));
        i == 0 ? trazo.moveTo(o.dx, o.dy) : trazo.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        trazo,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    curva((p) => p.promedio, promedio);
    curva((p) => p.mejor, mejor);
  }

  @override
  bool shouldRepaint(_PintorConvergencia anterior) => anterior.historial != historial;
}
