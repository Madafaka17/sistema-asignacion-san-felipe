import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/sesion_controlador.dart';
import '../componentes/boton_asincrono.dart';
import '../componentes/mensajes.dart';

/// HU-01: ingreso con usuario y contraseña (wireframe W-01).
class PantallaIngreso extends StatefulWidget {
  const PantallaIngreso({super.key});

  @override
  State<PantallaIngreso> createState() => _PantallaIngresoState();
}

class _PantallaIngresoState extends State<PantallaIngreso> {
  final _formulario = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  bool _ocultar = true;

  @override
  void dispose() {
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formulario.currentState!.validate()) return;
    await context.read<SesionControlador>().ingresar(_usuario.text, _contrasena.text);
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionControlador>();
    final tema = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formulario,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.directions_bus_filled, size: 48, color: tema.colorScheme.primary),
                        const SizedBox(height: 8),
                        Text('Transportes San Felipe', textAlign: TextAlign.center, style: tema.textTheme.headlineSmall),
                        Text('Asignación de recursos', textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
                        const SizedBox(height: 24),
                        if (sesion.aviso != null) ...[
                          Text(sesion.aviso!, key: const Key('aviso_sesion'), style: TextStyle(color: tema.colorScheme.tertiary)),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          key: const Key('campo_usuario'),
                          controller: _usuario,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person)),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Ingrese su usuario' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('campo_contrasena'),
                          controller: _contrasena,
                          obscureText: _ocultar,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _ingresar(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
                              icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _ocultar = !_ocultar),
                            ),
                          ),
                          validator: (v) => (v ?? '').isEmpty ? 'Ingrese su contraseña' : null,
                        ),
                        const SizedBox(height: 16),
                        BannerError(mensaje: sesion.error),
                        if (sesion.error != null) const SizedBox(height: 12),
                        BotonAsincrono(
                          key: const Key('boton_ingresar'),
                          etiqueta: 'Ingresar',
                          icono: Icons.login,
                          ocupado: sesion.ocupado,
                          alPresionar: _ingresar,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
