import 'dart:convert';

import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/operacion_controladores.dart';
import '../../controladores/registros_controladores.dart';
import '../componentes/dialogo_formulario.dart';
import '../componentes/mensajes.dart';
import '../componentes/tabla_datos.dart';
import '../formato.dart';

/// HU-01 (administrador): usuarios y su rol (wireframe W-01b).
class PantallaUsuarios extends StatelessWidget {
  const PantallaUsuarios({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UsuariosControlador>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EncabezadoPantalla(
        titulo: 'Usuarios',
        descripcion: 'Cada trabajador accede solo a las funciones de su rol',
        acciones: [
          FilledButton.icon(
            key: const Key('boton_nuevo_usuario'),
            icon: const Icon(Icons.person_add),
            label: const Text('Nuevo usuario'),
            onPressed: c.ocupado
                ? null
                : () async {
                    final ok = await DialogoFormulario.mostrar(context, controlador: c, constructor: () => const _FormularioUsuario());
                    if (ok == true && context.mounted) mostrarAviso(context, 'Usuario registrado');
                  },
          ),
        ],
      ),
      if (c.ocupado) const LinearProgressIndicator(),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerError(mensaje: c.error, alCerrar: c.limpiarError)),
      Expanded(
        child: SingleChildScrollView(
          child: TablaDatos<Usuario>(
            filas: c.usuarios,
            columnas: [
              ColumnaTabla('Usuario', (u) => Text(u.nombreUsuario)),
              ColumnaTabla('Nombre', (u) => Text(u.nombreCompleto)),
              ColumnaTabla('Rol', (u) => Text(u.rol.etiqueta)),
              ColumnaTabla('Activo', (u) => Icon(u.activo ? Icons.check : Icons.block)),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _FormularioUsuario extends StatefulWidget {
  const _FormularioUsuario();

  @override
  State<_FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends State<_FormularioUsuario> {
  final _usuario = TextEditingController();
  final _nombre = TextEditingController();
  final _contrasena = TextEditingController();
  Rol _rol = Rol.despacho;

  @override
  void dispose() {
    for (final t in [_usuario, _nombre, _contrasena]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<UsuariosControlador>();
    return DialogoFormulario<UsuariosControlador>(
      titulo: 'Nuevo usuario',
      alGuardar: () => c.crear(SolicitudUsuario(
        nombreUsuario: _usuario.text.trim().toLowerCase(),
        nombreCompleto: _nombre.text.trim(),
        rol: _rol,
        contrasena: _contrasena.text,
      )),
      campos: (e) => [
        campoTexto(controlador: _usuario, etiqueta: 'Usuario', ayuda: 'Minúsculas, dígitos, punto o guion bajo', errorServidor: e['nombreUsuario']),
        campoTexto(controlador: _nombre, etiqueta: 'Nombre completo', errorServidor: e['nombreCompleto']),
        DropdownButtonFormField<Rol>(
          initialValue: _rol,
          decoration: InputDecoration(labelText: 'Rol', errorText: e['rol']),
          items: [for (final r in Rol.values) DropdownMenuItem(value: r, child: Text(r.etiqueta))],
          onChanged: (v) => setState(() => _rol = v ?? _rol),
        ),
        TextFormField(
          controller: _contrasena,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Contraseña inicial',
            helperText: 'Al menos 8 caracteres con letras y números',
            errorText: e['contrasena'],
          ),
          validator: (v) => (v ?? '').length < 8 ? 'Al menos 8 caracteres' : null,
        ),
      ],
    );
  }
}

/// Bitácora (sección 3.6 y RNF-06).
class PantallaBitacora extends StatelessWidget {
  const PantallaBitacora({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AdministracionControlador>();
    final pagina = c.bitacora;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EncabezadoPantalla(
        titulo: 'Bitácora',
        descripcion: 'Quién hizo qué y cuándo',
        acciones: [
          if (pagina != null) ...[
            IconButton(
              tooltip: 'Anterior',
              icon: const Icon(Icons.chevron_left),
              onPressed: pagina.pagina > 1 && !c.ocupado ? () => c.cargarBitacora(pagina: pagina.pagina - 1) : null,
            ),
            Text('Página ${pagina.pagina} de ${pagina.totalPaginas == 0 ? 1 : pagina.totalPaginas}'),
            IconButton(
              tooltip: 'Siguiente',
              icon: const Icon(Icons.chevron_right),
              onPressed: pagina.pagina < pagina.totalPaginas && !c.ocupado ? () => c.cargarBitacora(pagina: pagina.pagina + 1) : null,
            ),
          ],
        ],
      ),
      if (c.ocupado) const LinearProgressIndicator(),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerError(mensaje: c.error, alCerrar: c.limpiarError)),
      Expanded(
        child: SingleChildScrollView(
          child: TablaDatos<EntradaBitacora>(
            filas: pagina?.elementos ?? const [],
            columnas: [
              ColumnaTabla('Fecha y hora', (e) => Text(fechaHora(e.fechaHora))),
              ColumnaTabla('Usuario', (e) => Text(e.usuario ?? '—')),
              ColumnaTabla('Acción', (e) => Text(e.accion)),
              ColumnaTabla('Entidad', (e) => Text('${e.entidad}${e.entidadId == null ? '' : ' #${e.entidadId}'}')),
              ColumnaTabla('Detalle', (e) => ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(jsonEncode(e.detalle), maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
            ],
          ),
        ),
      ),
    ]);
  }
}

/// Parámetros vigentes de `config/parametros.yaml` (solo lectura: se
/// cambian en el archivo, RNF-07).
class PantallaParametros extends StatelessWidget {
  const PantallaParametros({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AdministracionControlador>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Parámetros del sistema', style: Theme.of(context).textTheme.headlineSmall),
      const Text('Se modifican en config/parametros.yaml y se aplican al reiniciar el servidor.'),
      const SizedBox(height: 12),
      BannerError(mensaje: c.error),
      for (final seccion in c.parametros.entries)
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(seccion.key),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(seccion.value),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
    ]);
  }
}
