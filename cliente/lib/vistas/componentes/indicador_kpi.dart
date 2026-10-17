import 'package:flutter/material.dart';

/// Tarjeta con un indicador (Φ, F(X), PSR, PSA…).
class IndicadorKpi extends StatelessWidget {
  const IndicadorKpi({
    super.key,
    required this.titulo,
    required this.valor,
    this.detalle,
    this.color,
    this.ancho = 168,
  });

  final String titulo;
  final String valor;
  final String? detalle;
  final Color? color;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SizedBox(
      width: ancho,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: tema.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
              if (detalle != null)
                Text(detalle!, style: tema.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
