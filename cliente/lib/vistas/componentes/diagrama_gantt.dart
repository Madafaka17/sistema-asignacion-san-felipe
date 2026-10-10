import 'dart:math' as math;

import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';

/// Diagrama de Gantt de la programación por vehículo: cada barra es un
/// servicio de su salida a su término; los cruces se muestran en rojo.
class DiagramaGantt extends StatelessWidget {
  const DiagramaGantt({super.key, required this.asignaciones});

  final List<Asignacion> asignaciones;

  static const _altoFila = 36.0;
  static const _anchoEtiqueta = 64.0;
  static const _pixelesPorMinuto = 1.6;

  @override
  Widget build(BuildContext context) {
    final conRecursos = [for (final a in asignaciones) if (a.tieneRecursos) a];
    if (conRecursos.isEmpty) return const Center(child: Text('No hay servicios asignados'));
    final vehiculos = {for (final a in conRecursos) a.codigoVehiculo ?? '${a.vehiculoId}'}.toList()..sort();
    final inicio = (conRecursos.map((a) => a.salida!).reduce(math.min) ~/ 60) * 60;
    final fin = ((conRecursos.map((a) => a.fin!).reduce(math.max) + 59) ~/ 60) * 60;
    final ancho = _anchoEtiqueta + (fin - inicio) * _pixelesPorMinuto + 16;
    final alto = 28 + vehiculos.length * _altoFila;
    final tema = Theme.of(context);
    return Semantics(
      label: 'Diagrama de Gantt de ${conRecursos.length} servicios en ${vehiculos.length} vehículos',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: ancho,
          height: alto,
          child: Stack(children: [
            CustomPaint(
              size: Size(ancho, alto),
              painter: _PintorRejilla(
                inicio: inicio,
                fin: fin,
                filas: vehiculos,
                color: tema.colorScheme.outlineVariant,
                texto: tema.textTheme.bodySmall!,
              ),
            ),
            for (final a in conRecursos)
              Positioned(
                left: _anchoEtiqueta + (a.salida! - inicio) * _pixelesPorMinuto,
                top: 28 + vehiculos.indexOf(a.codigoVehiculo ?? '${a.vehiculoId}') * _altoFila + 4,
                width: math.max(4, (a.fin! - a.salida!) * _pixelesPorMinuto),
                height: _altoFila - 8,
                child: Tooltip(
                  message: '${a.codigoServicio} · ${a.codigoRuta} · ${a.codigoConductor}\n'
                      '${minutosAHora(a.salida!)}–${minutosAHora(a.fin!)}'
                      '${a.motivo == null ? '' : '\n${a.motivo}'}',
                  child: Container(
                    key: Key('gantt_${a.codigoServicio}'),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: a.estado == EstadoAsignacion.conflicto ? tema.colorScheme.error : tema.colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${a.codigoServicio} ${a.codigoConductor ?? ''}',
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                      style: tema.textTheme.labelSmall?.copyWith(
                        color: a.estado == EstadoAsignacion.conflicto ? tema.colorScheme.onError : tema.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _PintorRejilla extends CustomPainter {
  _PintorRejilla({required this.inicio, required this.fin, required this.filas, required this.color, required this.texto});

  final int inicio;
  final int fin;
  final List<String> filas;
  final Color color;
  final TextStyle texto;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 1;
    void rotulo(String t, Offset o) =>
        (TextPainter(text: TextSpan(text: t, style: texto), textDirection: TextDirection.ltr)..layout()).paint(canvas, o);
    for (var m = inicio; m <= fin; m += 60) {
      final x = DiagramaGantt._anchoEtiqueta + (m - inicio) * DiagramaGantt._pixelesPorMinuto;
      canvas.drawLine(Offset(x, 22), Offset(x, size.height), pincel);
      rotulo(minutosAHora(m), Offset(x + 2, 2));
    }
    for (final (i, fila) in filas.indexed) {
      final y = 28 + i * DiagramaGantt._altoFila;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pincel);
      rotulo(fila, Offset(4, y + 10));
    }
  }

  @override
  bool shouldRepaint(_PintorRejilla anterior) =>
      anterior.inicio != inicio || anterior.fin != fin || anterior.filas.length != filas.length;
}
