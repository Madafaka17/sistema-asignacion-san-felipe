import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/registros_controladores.dart';
import '../componentes/dialogo_formulario.dart';
import '../componentes/mensajes.dart';
import '../componentes/tabla_datos.dart';

/// HU-02: vehículos con su estado, capacidad y conductores autorizados
/// —habitual y reemplazos, sección 3.1.2— (wireframe W-02).
class PantallaVehiculos extends StatelessWidget {
  const PantallaVehiculos({super.key, this.editable = true});

  final bool editable;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VehiculosControlador>();
    final operativos = c.vehiculos.where((v) => v.disponible).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoPantalla(
          titulo: 'Flota',
          descripcion: '$operativos de ${c.vehiculos.length} unidades operativas',
          acciones: [
            if (editable)
              FilledButton.icon(
                key: const Key('boton_nuevo_vehiculo'),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo vehículo'),
                onPressed: c.ocupado ? null : () => _abrir(context, c, null),
              ),
          ],
        ),
        if (c.ocupado) const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerError(mensaje: c.error, alCerrar: c.limpiarError)),
        Expanded(
          child: SingleChildScrollView(
            child: TablaDatos<Vehiculo>(
              filas: c.vehiculos,
              claveFila: (v) => ValueKey('vehiculo_${v.codigo}'),
              columnas: [
                ColumnaTabla('Código', (v) => Text(v.codigo)),
                ColumnaTabla('Placa', (v) => Text(v.placa)),
                ColumnaTabla('Categoría', (v) => Text(v.categoria.valor)),
                ColumnaTabla('Asientos', (v) => Text('${v.capacidad}'), numerica: true),
                ColumnaTabla('Estado', (v) => Chip(
                      avatar: Icon(v.disponible ? Icons.check_circle : Icons.build, size: 18),
                      label: Text(v.estado.etiqueta),
                    )),
                ColumnaTabla('Habitual · reemplazos', (v) {
                  final a = c.autorizadosDe(v.id);
                  final habitual = a.conductorHabitualId == null ? '—' : c.codigoConductor(a.conductorHabitualId!);
                  return Text(a.reemplazos.isEmpty ? habitual : '$habitual · ${a.reemplazos.map(c.codigoConductor).join(', ')}');
                }),
                if (editable)
                  ColumnaTabla('', (v) => Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Editar ${v.codigo}',
                          icon: const Icon(Icons.edit),
                          onPressed: c.ocupado ? null : () => _abrir(context, c, v),
                        ),
                        IconButton(
                          key: ValueKey('conductores_${v.codigo}'),
                          tooltip: 'Conductores autorizados de ${v.codigo}',
                          icon: const Icon(Icons.badge),
                          onPressed: c.ocupado ? null : () => _conductores(context, c, v),
                        ),
                      ])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _abrir(BuildContext context, VehiculosControlador c, Vehiculo? vehiculo) async {
    final guardado = await DialogoFormulario.mostrar(context, controlador: c, constructor: () => _FormularioVehiculo(vehiculo));
    if (guardado == true && context.mounted) mostrarAviso(context, 'Vehículo guardado');
  }

  Future<void> _conductores(BuildContext context, VehiculosControlador c, Vehiculo vehiculo) async {
    final guardado =
        await DialogoFormulario.mostrar(context, controlador: c, constructor: () => _FormularioConductores(vehiculo));
    if (guardado == true && context.mounted) mostrarAviso(context, 'Conductores de ${vehiculo.codigo} guardados');
  }
}

/// `chab(v)` y `C_v^R`: solo ellos pueden conducir la unidad en la
/// programación (ecuación 1).
class _FormularioConductores extends StatefulWidget {
  const _FormularioConductores(this.vehiculo);

  final Vehiculo vehiculo;

  @override
  State<_FormularioConductores> createState() => _FormularioConductoresState();
}

class _FormularioConductoresState extends State<_FormularioConductores> {
  late final _actual = context.read<VehiculosControlador>().autorizadosDe(widget.vehiculo.id);
  late int? _habitual = _actual.conductorHabitualId;
  late final _reemplazos = {..._actual.reemplazos};

  @override
  Widget build(BuildContext context) {
    final c = context.read<VehiculosControlador>();
    return DialogoFormulario<VehiculosControlador>(
      titulo: 'Conductores autorizados de ${widget.vehiculo.codigo}',
      claveGuardar: const Key('boton_guardar_conductores'),
      alGuardar: () => c.asignarConductores(ConductoresAutorizados(
        vehiculoId: widget.vehiculo.id,
        conductorHabitualId: _habitual,
        reemplazos: [for (final r in _reemplazos) if (r != _habitual) r]..sort(),
      )),
      campos: (e) => [
        Text(
          'Solo el conductor habitual y los reemplazos autorizados pueden conducir la unidad; '
          'la programación prioriza al habitual y marca cada reemplazo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        DropdownButtonFormField<int?>(
          key: const Key('campo_conductor_habitual'),
          initialValue: _habitual,
          decoration: InputDecoration(labelText: 'Conductor habitual', errorText: e['conductorHabitualId']),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Sin conductor habitual')),
            for (final x in c.conductores) DropdownMenuItem<int?>(value: x.id, child: Text('${x.codigo} · ${x.nombreCompleto}')),
          ],
          onChanged: (v) => setState(() => _habitual = v),
        ),
        InputDecorator(
          decoration: InputDecoration(labelText: 'Reemplazos autorizados', errorText: e['reemplazos']),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final x in c.conductores)
              if (x.id != _habitual)
                FilterChip(
                  key: ValueKey('reemplazo_${x.codigo}'),
                  label: Text(x.codigo),
                  tooltip: x.nombreCompleto,
                  selected: _reemplazos.contains(x.id),
                  onSelected: (si) => setState(() => si ? _reemplazos.add(x.id) : _reemplazos.remove(x.id)),
                ),
          ]),
        ),
      ],
    );
  }
}

class _FormularioVehiculo extends StatefulWidget {
  const _FormularioVehiculo(this.vehiculo);

  final Vehiculo? vehiculo;

  @override
  State<_FormularioVehiculo> createState() => _FormularioVehiculoState();
}

class _FormularioVehiculoState extends State<_FormularioVehiculo> {
  late final _codigo = TextEditingController(text: widget.vehiculo?.codigo);
  late final _placa = TextEditingController(text: widget.vehiculo?.placa);
  late final _capacidad = TextEditingController(text: widget.vehiculo == null ? '' : '${widget.vehiculo!.capacidad}');
  late CategoriaVehiculo _categoria = widget.vehiculo?.categoria ?? CategoriaVehiculo.m2;
  late EstadoVehiculo _estado = widget.vehiculo?.estado ?? EstadoVehiculo.operativo;

  @override
  void dispose() {
    for (final t in [_codigo, _placa, _capacidad]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<VehiculosControlador>();
    return DialogoFormulario<VehiculosControlador>(
      titulo: widget.vehiculo == null ? 'Nuevo vehículo' : 'Editar ${widget.vehiculo!.codigo}',
      claveGuardar: const Key('boton_guardar_vehiculo'),
      alGuardar: () => c.guardar(Vehiculo(
        id: widget.vehiculo?.id ?? 0,
        codigo: _codigo.text.trim().toUpperCase(),
        placa: _placa.text.trim().toUpperCase(),
        capacidad: int.parse(_capacidad.text.trim()),
        categoria: _categoria,
        estado: _estado,
      )),
      campos: (errores) => [
        campoTexto(key: const Key('campo_codigo_vehiculo'), controlador: _codigo, etiqueta: 'Código de unidad', ayuda: 'Por ejemplo V-07', errorServidor: errores['codigo']),
        campoTexto(
          key: const Key('campo_placa'),
          controlador: _placa,
          etiqueta: 'Placa',
          ayuda: 'Formato ABC-123',
          errorServidor: errores['placa'],
          validar: (t) => Vehiculo.formatoPlaca.hasMatch(t.toUpperCase()) ? null : 'Formato ABC-123',
        ),
        campoTexto(
          key: const Key('campo_capacidad'),
          controlador: _capacidad,
          etiqueta: 'Asientos (Q_v)',
          teclado: TextInputType.number,
          errorServidor: errores['capacidad'],
          validar: (t) => validarEntero(t, minimo: 1, maximo: 100),
        ),
        DropdownButtonFormField<CategoriaVehiculo>(
          initialValue: _categoria,
          decoration: InputDecoration(labelText: 'Categoría vehicular', errorText: errores['categoria']),
          items: [for (final k in CategoriaVehiculo.values) DropdownMenuItem(value: k, child: Text(k.valor))],
          onChanged: (v) => setState(() => _categoria = v ?? _categoria),
        ),
        DropdownButtonFormField<EstadoVehiculo>(
          key: const Key('campo_estado_vehiculo'),
          initialValue: _estado,
          decoration: InputDecoration(labelText: 'Estado', errorText: errores['estado']),
          items: [for (final e in EstadoVehiculo.values) DropdownMenuItem(value: e, child: Text(e.etiqueta))],
          onChanged: (v) => setState(() => _estado = v ?? _estado),
        ),
      ],
    );
  }
}
