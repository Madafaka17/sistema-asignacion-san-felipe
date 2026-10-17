import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/controlador_base.dart';
import 'boton_asincrono.dart';
import 'mensajes.dart';

/// Diálogo de registro o edición. «Guardar» valida el formulario en el
/// cliente, llama a [alGuardar] y se cierra solo si el servidor aceptó el
/// registro; si lo rechaza, el error queda visible y los campos marcados.
class DialogoFormulario<C extends ControladorBase> extends StatefulWidget {
  const DialogoFormulario({
    super.key,
    required this.titulo,
    required this.campos,
    required this.alGuardar,
    this.claveGuardar,
    this.ancho = 480,
  });

  final String titulo;

  /// Recibe los errores por campo del servidor para mostrarlos.
  final List<Widget> Function(Map<String, String> erroresCampo) campos;
  final Future<bool> Function() alGuardar;
  final Key? claveGuardar;
  final double ancho;

  /// Abre el diálogo con el controlador [controlador] disponible dentro.
  static Future<bool?> mostrar<C extends ControladorBase>(
    BuildContext context, {
    required C controlador,
    required Widget Function() constructor,
  }) {
    controlador.limpiarError();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider<C>.value(value: controlador, child: constructor()),
    );
  }

  @override
  State<DialogoFormulario<C>> createState() => _DialogoFormularioState<C>();
}

class _DialogoFormularioState<C extends ControladorBase> extends State<DialogoFormulario<C>> {
  final _formulario = GlobalKey<FormState>();

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    final aceptado = await widget.alGuardar();
    if (aceptado && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<C>();
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: widget.ancho,
        child: Form(
          key: _formulario,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final campo in widget.campos(controlador.erroresCampo))
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: campo),
                BannerError(mensaje: controlador.error),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: controlador.ocupado ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        BotonAsincrono(
          key: widget.claveGuardar,
          etiqueta: 'Guardar',
          icono: Icons.save,
          ocupado: controlador.ocupado,
          alPresionar: _guardar,
        ),
      ],
    );
  }
}

/// Campo de texto con el error del servidor para ese campo.
TextFormField campoTexto({
  Key? key,
  required TextEditingController controlador,
  required String etiqueta,
  String? errorServidor,
  String? ayuda,
  String? Function(String)? validar,
  TextInputType? teclado,
  bool obligatorio = true,
  bool habilitado = true,
}) =>
    TextFormField(
      key: key,
      controller: controlador,
      enabled: habilitado,
      keyboardType: teclado,
      decoration: InputDecoration(labelText: etiqueta, helperText: ayuda, errorText: errorServidor),
      validator: (v) {
        final texto = (v ?? '').trim();
        if (obligatorio && texto.isEmpty) return 'Campo obligatorio';
        return validar?.call(texto);
      },
    );

String? validarEntero(String texto, {int minimo = 0, int? maximo}) {
  final n = int.tryParse(texto);
  if (n == null) return 'Ingrese un número entero';
  if (n < minimo) return 'Debe ser al menos $minimo';
  if (maximo != null && n > maximo) return 'Debe ser como máximo $maximo';
  return null;
}
