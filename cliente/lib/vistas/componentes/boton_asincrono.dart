import 'package:flutter/material.dart';

enum EstiloBoton { relleno, contorno, texto }

/// Botón que ejecuta una acción asíncrona y queda desactivado, con un
/// indicador de progreso, hasta que termina: el usuario no puede enviar dos
/// veces la misma solicitud (por ejemplo, registrar dos veces un servicio).
class BotonAsincrono extends StatefulWidget {
  const BotonAsincrono({
    super.key,
    required this.etiqueta,
    required this.alPresionar,
    this.icono,
    this.estilo = EstiloBoton.relleno,
    this.ocupado = false,
  });

  final String etiqueta;
  final IconData? icono;

  /// `null` desactiva el botón.
  final Future<void> Function()? alPresionar;
  final EstiloBoton estilo;

  /// Desactiva el botón por una operación en curso fuera de él (por
  /// ejemplo, mientras el controlador está ocupado).
  final bool ocupado;

  @override
  State<BotonAsincrono> createState() => _BotonAsincronoState();
}

class _BotonAsincronoState extends State<BotonAsincrono> {
  bool _enCurso = false;

  Future<void> _presionar() async {
    setState(() => _enCurso = true);
    try {
      await widget.alPresionar!();
    } finally {
      if (mounted) setState(() => _enCurso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activo = !_enCurso && !widget.ocupado && widget.alPresionar != null;
    final alPresionar = activo ? _presionar : null;
    final Widget icono = _enCurso
        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(widget.icono ?? Icons.check);
    final etiqueta = Text(widget.etiqueta);
    final mostrarIcono = widget.icono != null || _enCurso;
    return Semantics(
      button: true,
      enabled: activo,
      label: _enCurso ? '${widget.etiqueta}, en curso' : null,
      child: switch (widget.estilo) {
        EstiloBoton.relleno => mostrarIcono
            ? FilledButton.icon(onPressed: alPresionar, icon: icono, label: etiqueta)
            : FilledButton(onPressed: alPresionar, child: etiqueta),
        EstiloBoton.contorno => mostrarIcono
            ? OutlinedButton.icon(onPressed: alPresionar, icon: icono, label: etiqueta)
            : OutlinedButton(onPressed: alPresionar, child: etiqueta),
        EstiloBoton.texto => mostrarIcono
            ? TextButton.icon(onPressed: alPresionar, icon: icono, label: etiqueta)
            : TextButton(onPressed: alPresionar, child: etiqueta),
      },
    );
  }
}
