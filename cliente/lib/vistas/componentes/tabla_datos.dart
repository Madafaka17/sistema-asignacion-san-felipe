import 'package:flutter/material.dart';

class ColumnaTabla<T> {
  const ColumnaTabla(this.titulo, this.celda, {this.numerica = false});

  final String titulo;
  final Widget Function(T fila) celda;
  final bool numerica;
}

/// Tabla con desplazamiento horizontal en pantallas angostas.
class TablaDatos<T> extends StatelessWidget {
  const TablaDatos({
    super.key,
    required this.columnas,
    required this.filas,
    this.claveFila,
    this.resaltar,
    this.alSeleccionar,
    this.vacio = 'Sin registros',
  });

  final List<ColumnaTabla<T>> columnas;
  final List<T> filas;
  final LocalKey Function(T fila)? claveFila;

  /// Filas que se muestran resaltadas (por ejemplo, incidencias).
  final bool Function(T fila)? resaltar;
  final void Function(T fila)? alSeleccionar;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    if (filas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(vacio, style: Theme.of(context).textTheme.bodyLarge)),
      );
    }
    final esquema = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, restricciones) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: restricciones.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStatePropertyAll(esquema.surfaceContainerHighest),
            columns: [
              for (final c in columnas) DataColumn(label: Text(c.titulo), numeric: c.numerica),
            ],
            rows: [
              for (final fila in filas)
                DataRow(
                  color: resaltar?.call(fila) ?? false ? WidgetStatePropertyAll(esquema.errorContainer) : null,
                  onSelectChanged: alSeleccionar == null ? null : (_) => alSeleccionar!(fila),
                  cells: [
                    for (final (i, c) in columnas.indexed)
                      // La clave de la fila se pone en su primera celda para que las
                      // pruebas puedan encontrarla (DataRow no es un widget).
                      DataCell(i == 0 && claveFila != null ? KeyedSubtree(key: claveFila!(fila), child: c.celda(fila)) : c.celda(fila)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
