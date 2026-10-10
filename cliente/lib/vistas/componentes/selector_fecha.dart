import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';

import '../formato.dart';

/// Botón que muestra una fecha y abre el calendario para cambiarla.
class SelectorFecha extends StatelessWidget {
  const SelectorFecha({super.key, required this.fecha, required this.alCambiar, this.etiqueta = 'Turno'});

  final DateTime fecha;
  final ValueChanged<DateTime> alCambiar;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.calendar_month),
        label: Text('$etiqueta: ${fechaCorta(fecha)}'),
        onPressed: () async {
          final elegida = await showDatePicker(
            context: context,
            initialDate: DateTime(fecha.year, fecha.month, fecha.day),
            firstDate: DateTime(2024),
            lastDate: DateTime(2035),
          );
          if (elegida != null) alCambiar(soloFecha(elegida));
        },
      );
}
