import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/registros_controladores.dart';
import '../componentes/boton_asincrono.dart';
import '../componentes/dialogo_formulario.dart';
import '../componentes/mensajes.dart';
import '../componentes/tabla_datos.dart';

/// HU-04 y HU-05: rutas autorizadas, vehículos compatibles κ(v, r) y
/// salidas autorizadas (wireframe W-04/05, maestro–detalle).
class PantallaRutas extends StatelessWidget {
  const PantallaRutas({super.key, this.editable = true});

  final bool editable;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RutasControlador>();
    final ancha = MediaQuery.sizeOf(context).width >= 1100;
    final flota = {for (final v in c.flota) v.id: v.codigo};
    final maestro = TablaDatos<Ruta>(
      filas: c.rutas,
      claveFila: (r) => ValueKey('ruta_${r.codigo}'),
      alSeleccionar: c.seleccionar,
      columnas: [
        ColumnaTabla('Código', (r) => Text(r.codigo, style: TextStyle(fontWeight: r.id == c.seleccionada?.id ? FontWeight.bold : null))),
        ColumnaTabla('Origen – destino', (r) => Text(r.nombre)),
        ColumnaTabla('Duración', (r) => Text('${r.duracionMin} min'), numerica: true),
        ColumnaTabla('Compatibles', (r) => Text([for (final id in r.vehiculosCompatibles) flota[id] ?? '$id'].join(', '))),
        ColumnaTabla('Activa', (r) => Icon(r.activa ? Icons.check : Icons.block)),
        if (editable)
          ColumnaTabla('', (r) => IconButton(
                tooltip: 'Editar ${r.codigo}',
                icon: const Icon(Icons.edit),
                onPressed: c.ocupado ? null : () => _abrir(context, c, r),
              )),
      ],
    );
    final detalle = _Salidas(editable: editable);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoPantalla(
          titulo: 'Rutas autorizadas',
          descripcion: 'Seleccione una ruta para ver y registrar sus salidas',
          acciones: [
            if (editable)
              FilledButton.icon(
                key: const Key('boton_nueva_ruta'),
                icon: const Icon(Icons.add),
                label: const Text('Nueva ruta'),
                onPressed: c.ocupado ? null : () => _abrir(context, c, null),
              ),
          ],
        ),
        if (c.ocupado) const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerError(mensaje: c.error, alCerrar: c.limpiarError)),
        Expanded(
          child: ancha
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: SingleChildScrollView(child: maestro)),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 2, child: detalle),
                ])
              : ListView(children: [maestro, const Divider(), SizedBox(height: 360, child: detalle)]),
        ),
      ],
    );
  }

  Future<void> _abrir(BuildContext context, RutasControlador c, Ruta? ruta) async {
    final guardado = await DialogoFormulario.mostrar(context, controlador: c, constructor: () => _FormularioRuta(ruta));
    if (guardado == true && context.mounted) mostrarAviso(context, 'Ruta guardada');
  }
}

class _Salidas extends StatefulWidget {
  const _Salidas({required this.editable});

  final bool editable;

  @override
  State<_Salidas> createState() => _SalidasState();
}

class _SalidasState extends State<_Salidas> {
  final _hora = TextEditingController();
  final _formulario = GlobalKey<FormState>();

  @override
  void dispose() {
    _hora.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RutasControlador>();
    final ruta = c.seleccionada;
    final tema = Theme.of(context);
    if (ruta == null) return const Center(child: Text('Ninguna ruta seleccionada'));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Salidas autorizadas de ${ruta.codigo}', style: tema.textTheme.titleMedium),
        Text('Término = salida + ${ruta.duracionMin} min', style: tema.textTheme.bodySmall),
        const SizedBox(height: 8),
        if (widget.editable)
          Form(
            key: _formulario,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextFormField(
                  key: const Key('campo_hora_salida'),
                  controller: _hora,
                  decoration: InputDecoration(labelText: 'Hora (HH:MM)', errorText: c.erroresCampo['hora']),
                  validator: (t) => horaAMinutos(t ?? '') == null ? 'Hora HH:MM' : null,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: BotonAsincrono(
                  key: const Key('boton_agregar_salida'),
                  etiqueta: 'Agregar',
                  icono: Icons.add_alarm,
                  ocupado: c.ocupado,
                  alPresionar: () async {
                    if (!_formulario.currentState!.validate()) return;
                    if (await c.agregarSalida(horaAMinutos(_hora.text)!)) _hora.clear();
                  },
                ),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: c.salidas.isEmpty
              ? const Center(child: Text('Sin salidas registradas'))
              : SingleChildScrollView(
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in c.salidas)
                      InputChip(
                        key: Key('salida_${minutosAHora(s.hora)}'),
                        label: Text(minutosAHora(s.hora) + (s.duracionMin == null ? '' : ' (${s.duracionMin} min)')),
                        onDeleted: widget.editable && !c.ocupado ? () => c.eliminarSalida(s) : null,
                        deleteButtonTooltipMessage: 'Eliminar salida',
                      ),
                  ]),
                ),
        ),
      ]),
    );
  }
}

class _FormularioRuta extends StatefulWidget {
  const _FormularioRuta(this.ruta);

  final Ruta? ruta;

  @override
  State<_FormularioRuta> createState() => _FormularioRutaState();
}

class _FormularioRutaState extends State<_FormularioRuta> {
  late final _codigo = TextEditingController(text: widget.ruta?.codigo);
  late final _origen = TextEditingController(text: widget.ruta?.origen ?? 'Soritor');
  late final _destino = TextEditingController(text: widget.ruta?.destino);
  late final _duracion = TextEditingController(text: widget.ruta == null ? '' : '${widget.ruta!.duracionMin}');
  late bool _activa = widget.ruta?.activa ?? true;
  late final Set<int> _compatibles = {...?widget.ruta?.vehiculosCompatibles};

  @override
  void dispose() {
    for (final t in [_codigo, _origen, _destino, _duracion]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<RutasControlador>();
    return DialogoFormulario<RutasControlador>(
      titulo: widget.ruta == null ? 'Nueva ruta' : 'Editar ${widget.ruta!.codigo}',
      claveGuardar: const Key('boton_guardar_ruta'),
      alGuardar: () => c.guardar(Ruta(
        id: widget.ruta?.id ?? 0,
        codigo: _codigo.text.trim().toUpperCase(),
        origen: _origen.text.trim(),
        destino: _destino.text.trim(),
        duracionMin: int.parse(_duracion.text.trim()),
        activa: _activa,
        vehiculosCompatibles: _compatibles.toList()..sort(),
      )),
      campos: (e) => [
        campoTexto(controlador: _codigo, etiqueta: 'Código', ayuda: 'Por ejemplo R-03', errorServidor: e['codigo']),
        campoTexto(controlador: _origen, etiqueta: 'Origen', errorServidor: e['origen']),
        campoTexto(controlador: _destino, etiqueta: 'Destino', errorServidor: e['destino']),
        campoTexto(
          key: const Key('campo_duracion_ruta'),
          controlador: _duracion,
          etiqueta: 'Duración estimada (min)',
          teclado: TextInputType.number,
          errorServidor: e['duracionMin'],
          // La misma regla que valida el servidor (HU-04, escenario de error).
          validar: (t) => (int.tryParse(t) ?? 0) <= 0 ? 'La duración debe ser mayor que cero' : null,
        ),
        Text('Vehículos compatibles', style: Theme.of(context).textTheme.labelLarge),
        Wrap(spacing: 8, children: [
          for (final v in c.flota)
            FilterChip(
              label: Text('${v.codigo} (${v.capacidad})'),
              selected: _compatibles.contains(v.id),
              onSelected: (s) => setState(() => s ? _compatibles.add(v.id) : _compatibles.remove(v.id)),
            ),
        ]),
        if (e['vehiculosCompatibles'] != null)
          Text(e['vehiculosCompatibles']!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activa'),
          value: _activa,
          onChanged: (v) => setState(() => _activa = v),
        ),
      ],
    );
  }
}
