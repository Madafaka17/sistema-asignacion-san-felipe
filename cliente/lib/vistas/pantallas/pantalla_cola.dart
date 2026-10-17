import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/registros_controladores.dart';
import '../componentes/dialogo_formulario.dart';
import '../componentes/mensajes.dart';
import '../componentes/selector_fecha.dart';
import '../componentes/tabla_datos.dart';
import '../formato.dart';

/// Cola de despacho de cada ruta (sección 3.1.2; wireframe W-12): las
/// unidades salen por orden de llegada. La posición `π` define la unidad que
/// corresponde a cada servicio (`v0(s)`) y la siguiente elegible (`v1(s)`).
class PantallaCola extends StatelessWidget {
  const PantallaCola({super.key, this.editable = true});

  final bool editable;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ColaControlador>();
    final ruta = c.ruta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoPantalla(
          titulo: 'Cola de despacho',
          descripcion: ruta == null
              ? 'No hay rutas activas'
              : '${ruta.codigo} · ${ruta.nombre}: ${c.enEspera} '
                  '${c.enEspera == 1 ? 'unidad espera' : 'unidades esperan'} turno',
          acciones: [
            SelectorFecha(fecha: c.fecha, alCambiar: c.cambiarFecha),
            if (editable)
              FilledButton.icon(
                key: const Key('boton_registrar_llegada'),
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Registrar llegada'),
                onPressed: c.ocupado || ruta == null ? null : () => _registrar(context, c),
              ),
          ],
        ),
        if (c.ocupado) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BannerError(mensaje: c.error, alCerrar: c.limpiarError),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final r in c.rutas)
                ChoiceChip(
                  key: ValueKey('cola_ruta_${r.codigo}'),
                  label: Text('${r.codigo} · ${r.destino}'),
                  selected: r.id == ruta?.id,
                  onSelected: c.ocupado ? null : (_) => c.seleccionarRuta(r.id),
                ),
            ]),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: TablaDatos<EntradaCola>(
              key: const Key('tabla_cola'),
              filas: c.entradas,
              claveFila: (e) => ValueKey('entrada_${e.posicion}'),
              resaltar: (e) => !e.activa,
              vacio: ruta == null
                  ? 'Registre una ruta activa'
                  : 'Ninguna unidad llegó a la cola de ${ruta.codigo} el ${fechaCorta(c.fecha)}',
              columnas: [
                ColumnaTabla('Posición', (e) => Text('${e.posicion}'), numerica: true),
                ColumnaTabla('Unidad', (e) => Text(e.codigoVehiculo ?? '${e.vehiculoId}')),
                ColumnaTabla('Llegada', (e) => Text(minutosAHora(e.llegada))),
                ColumnaTabla('Turno', (e) => Chip(
                      avatar: Icon(
                        !e.activa ? Icons.logout : (e.servicioId == null ? Icons.hourglass_top : Icons.event_available),
                        size: 18,
                      ),
                      label: Text(!e.activa
                          ? 'Dejó la cola'
                          : e.servicioId == null
                              ? 'Espera turno'
                              : 'Servicio ${e.codigoServicio}'),
                    )),
                if (editable)
                  ColumnaTabla('', (e) => IconButton(
                        key: ValueKey('retirar_${e.posicion}'),
                        tooltip: 'Retirar ${e.codigoVehiculo} de la cola',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: !e.activa || c.ocupado ? null : () => c.retirar(e),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _registrar(BuildContext context, ColaControlador c) async {
    final guardado = await DialogoFormulario.mostrar(context, controlador: c, constructor: () => const _FormularioLlegada());
    if (guardado == true && context.mounted) mostrarAviso(context, 'Llegada registrada');
  }
}

class _FormularioLlegada extends StatefulWidget {
  const _FormularioLlegada();

  @override
  State<_FormularioLlegada> createState() => _FormularioLlegadaState();
}

class _FormularioLlegadaState extends State<_FormularioLlegada> {
  int? _vehiculo;
  late final _llegada = TextEditingController(text: () {
    final ahora = DateTime.now();
    return minutosAHora(ahora.hour * 60 + ahora.minute);
  }());

  @override
  void dispose() {
    _llegada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<ColaControlador>();
    final ruta = c.ruta!;
    return DialogoFormulario<ColaControlador>(
      titulo: 'Llegada a la cola de ${ruta.codigo} · ${fechaCorta(c.fecha)}',
      claveGuardar: const Key('boton_guardar_llegada'),
      alGuardar: () => c.registrarLlegada(_vehiculo!, horaAMinutos(_llegada.text)!),
      campos: (e) => [
        Text(
          'La unidad recibe la posición siguiente a la última registrada: las unidades salen por orden de llegada.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        DropdownButtonFormField<int>(
          key: const Key('campo_unidad_llegada'),
          initialValue: _vehiculo,
          decoration: InputDecoration(labelText: 'Unidad', errorText: e['vehiculoId']),
          items: [
            for (final v in c.unidadesElegibles) DropdownMenuItem(value: v.id, child: Text('${v.codigo} · ${v.placa}')),
          ],
          validator: (v) => v == null ? 'Seleccione la unidad' : null,
          onChanged: (v) => setState(() => _vehiculo = v),
        ),
        campoTexto(
          key: const Key('campo_hora_llegada'),
          controlador: _llegada,
          etiqueta: 'Hora de llegada',
          ayuda: 'HH:MM',
          errorServidor: e['llegada'],
          validar: (t) => horaAMinutos(t) == null ? 'Hora HH:MM' : null,
        ),
      ],
    );
  }
}
