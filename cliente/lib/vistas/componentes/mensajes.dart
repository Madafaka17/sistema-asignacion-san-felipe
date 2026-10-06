import 'package:flutter/material.dart';

/// Mensaje de error de la última operación del controlador.
class BannerError extends StatelessWidget {
  const BannerError({super.key, required this.mensaje, this.alCerrar});

  final String? mensaje;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    if (mensaje == null) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: esquema.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          key: const Key('mensaje_error'),
          leading: Icon(Icons.error_outline, color: esquema.onErrorContainer),
          title: Text(mensaje!, style: TextStyle(color: esquema.onErrorContainer)),
          trailing: alCerrar == null
              ? null
              : IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: alCerrar),
        ),
      ),
    );
  }
}

void mostrarAviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating));
}

/// Encabezado común de las pantallas: título, descripción y acciones.
class EncabezadoPantalla extends StatelessWidget {
  const EncabezadoPantalla({super.key, required this.titulo, this.descripcion, this.acciones = const []});

  final String titulo;
  final String? descripcion;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo, style: tema.textTheme.headlineSmall),
              if (descripcion != null) Text(descripcion!, style: tema.textTheme.bodyMedium),
            ],
          ),
          Wrap(spacing: 8, runSpacing: 8, children: acciones),
        ],
      ),
    );
  }
}
