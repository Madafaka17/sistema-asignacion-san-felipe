import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/registros_controladores.dart';
import '../componentes/dialogo_formulario.dart';
import '../componentes/mensajes.dart';
import '../componentes/selector_fecha.dart';
import '../componentes/tabla_datos.dart';
import '../formato.dart';

/// HU-06: servicios del turno con su ruta y prioridad (wireframe W-06).
class PantallaServicios extends StatelessWidget {
  const PantallaServicios({super.key, this.editable = true});

  final bool editable;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ServiciosControlador>();
    final rutas = {for (final r in c.rutas) r.id: r};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoPantalla(
          titulo: 'Servicios del turno',
          descripcion: '${c.servicios.where((s) => s.estado == EstadoServicio.pendiente).length} pendientes',
          acciones: [
            SelectorFecha(fecha: c.fecha, alCambiar: c.cambiarFecha),
            if (editable)
              FilledButton.icon(
                key: const Key('boton_nuevo_servicio'),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo servicio'),
                onPressed: c.ocupado ? null : () => _abrir(context, c, null),
              ),
          ],
        ),
        if (c.ocupado) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BannerError(mensaje: c.error, alCerrar: c.limpiarError),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: TablaDatos<ServicioProgramado>(
              key: const Key('tabla_servicios'),
              filas: c.servicios,
              claveFila: (s) => ValueKey('servicio_${s.codigo}'),
              vacio: 'No hay servicios registrados para el ${fechaCorta(c.fecha)}',
              columnas: [
                ColumnaTabla('Código', (s) => Text(s.codigo)),
                ColumnaTabla('Ruta', (s) => Text(s.codigoRuta ?? rutas[s.rutaId]?.codigo ?? '${s.rutaId}')),
                ColumnaTabla('Hora', (s) => Text(minutosAHora(s.horaSolicitada))),
                ColumnaTabla('Prioridad', (s) => Text(_prioridades[s.prioridad] ?? '${s.prioridad}')),
                ColumnaTabla('Asientos', (s) => Text('${s.capacidadRequerida}'), numerica: true),
                ColumnaTabla('Estado', (s) => Chip(label: Text(s.estado.etiqueta))),
                if (editable)
                  ColumnaTabla('', (s) => Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Editar ${s.codigo}',
                          icon: const Icon(Icons.edit),
                          onPressed: s.estado == EstadoServicio.pendiente && !c.ocupado ? () => _abrir(context, c, s) : null,
                        ),
                        IconButton(
                          tooltip: 'Cancelar ${s.codigo}',
                          icon: const Icon(Icons.cancel),
                          onPressed: s.estado == EstadoServicio.cancelado || c.ocupado ? null : () => c.cancelar(s),
                        ),
                      ])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _abrir(BuildContext context, ServiciosControlador c, ServicioProgramado? servicio) async {
    final guardado = await DialogoFormulario.mostrar(
      context,
      controlador: c,
      constructor: () => _FormularioServicio(servicio: servicio),
    );
    if (guardado == true && context.mounted) {
      mostrarAviso(context, servicio == null ? 'Servicio registrado' : 'Servicio actualizado');
    }
  }
}

const _prioridades = {3: 'Alta', 2: 'Media', 1: 'Baja'};

class _FormularioServicio extends StatefulWidget {
  const _FormularioServicio({this.servicio});

  final ServicioProgramado? servicio;

  @override
  State<_FormularioServicio> createState() => _FormularioServicioState();
}

class _FormularioServicioState extends State<_FormularioServicio> {
  late final _codigo = TextEditingController(text: widget.servicio?.codigo);
  late final _capacidad = TextEditingController(text: '${widget.servicio?.capacidadRequerida ?? 1}');
  late int? _rutaId = widget.servicio?.rutaId;
  late int? _hora = widget.servicio?.horaSolicitada;
  late int _prioridad = widget.servicio?.prioridad ?? 2;

  @override
  void initState() {
    super.initState();
    if (_rutaId != null) context.read<ServiciosControlador>().cargarSalidas(_rutaId!);
  }

  @override
  void dispose() {
    _codigo.dispose();
    _capacidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ServiciosControlador>();
    final salidas = _rutaId == null ? const <SalidaAutorizada>[] : c.salidasDe(_rutaId!);
    return DialogoFormulario<ServiciosControlador>(
      titulo: widget.servicio == null ? 'Nuevo servicio · ${fechaCorta(c.fecha)}' : 'Editar ${widget.servicio!.codigo}',
      claveGuardar: const Key('boton_guardar_servicio'),
      alGuardar: () => c.guardar(ServicioProgramado(
        id: widget.servicio?.id ?? 0,
        codigo: _codigo.text.trim().toUpperCase(),
        fecha: c.fecha,
        rutaId: _rutaId!,
        horaSolicitada: _hora!,
        prioridad: _prioridad,
        capacidadRequerida: int.parse(_capacidad.text.trim()),
      )),
      campos: (errores) => [
        campoTexto(
          key: const Key('campo_codigo_servicio'),
          controlador: _codigo,
          etiqueta: 'Código',
          ayuda: 'Por ejemplo S-115',
          errorServidor: errores['codigo'],
          validar: (t) => t.length > 12 ? 'Máximo 12 caracteres' : null,
        ),
        DropdownButtonFormField<int>(
          key: const Key('campo_ruta_servicio'),
          initialValue: _rutaId,
          decoration: InputDecoration(labelText: 'Ruta', errorText: errores['rutaId']),
          items: [
            for (final r in c.rutas) DropdownMenuItem(value: r.id, child: Text('${r.codigo} · ${r.nombre}')),
          ],
          validator: (v) => v == null ? 'Seleccione una ruta' : null,
          onChanged: (v) {
            setState(() {
              _rutaId = v;
              _hora = null;
            });
            if (v != null) c.cargarSalidas(v);
          },
        ),
        DropdownButtonFormField<int>(
          key: ValueKey('campo_hora_servicio_$_rutaId'),
          initialValue: salidas.any((s) => s.hora == _hora) ? _hora : null,
          decoration: InputDecoration(
            labelText: 'Hora de salida autorizada',
            errorText: errores['horaSolicitada'],
            helperText: _rutaId == null ? 'Primero seleccione la ruta' : null,
          ),
          items: [
            for (final s in salidas) DropdownMenuItem(value: s.hora, child: Text(minutosAHora(s.hora))),
          ],
          validator: (v) => v == null ? 'Seleccione una hora autorizada' : null,
          onChanged: (v) => setState(() => _hora = v),
        ),
        DropdownButtonFormField<int>(
          key: const Key('campo_prioridad_servicio'),
          initialValue: _prioridad,
          decoration: InputDecoration(labelText: 'Prioridad', errorText: errores['prioridad']),
          items: [for (final e in _prioridades.entries) DropdownMenuItem(value: e.key, child: Text('${e.value} (${e.key})'))],
          onChanged: (v) => setState(() => _prioridad = v ?? 2),
        ),
        campoTexto(
          key: const Key('campo_capacidad_servicio'),
          controlador: _capacidad,
          etiqueta: 'Asientos requeridos',
          teclado: TextInputType.number,
          errorServidor: errores['capacidadRequerida'],
          validar: (t) => validarEntero(t, minimo: 1, maximo: 100),
        ),
      ],
    );
  }
}
