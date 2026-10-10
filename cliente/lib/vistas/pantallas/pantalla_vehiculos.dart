import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/registros_controladores.dart';
import '../componentes/dialogo_formulario.dart';
import '../componentes/mensajes.dart';
import '../componentes/tabla_datos.dart';

/// HU-02: vehículos con su estado y capacidad (wireframe W-02).
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
                if (editable)
                  ColumnaTabla('', (v) => IconButton(
                        tooltip: 'Editar ${v.codigo}',
                        icon: const Icon(Icons.edit),
                        onPressed: c.ocupado ? null : () => _abrir(context, c, v),
                      )),
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
