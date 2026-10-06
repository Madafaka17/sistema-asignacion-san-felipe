import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/operacion_controladores.dart';
import '../componentes/boton_asincrono.dart';
import '../componentes/diagrama_gantt.dart';
import '../componentes/dialogo_formulario.dart';
import '../componentes/grafico_convergencia.dart';
import '../componentes/indicador_kpi.dart';
import '../componentes/mensajes.dart';
import '../componentes/selector_fecha.dart';
import '../componentes/tabla_datos.dart';
import '../formato.dart';

/// HU-07, HU-08 y HU-09: generar la propuesta, revisarla por servicio,
/// ajustarla y aprobarla (wireframe W-07/08/09; Figura 5 de la tesis).
class PantallaProgramacion extends StatelessWidget {
  const PantallaProgramacion({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ProgramacionControlador>();
    final p = c.actual;
    final esquema = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoPantalla(
            titulo: 'Programación del turno',
            descripcion: 'El sistema propone; el encargado de operaciones revisa, ajusta y aprueba',
            acciones: [
              SelectorFecha(fecha: c.fecha, alCambiar: c.cambiarFecha),
              BotonAsincrono(
                key: const Key('boton_generar'),
                etiqueta: c.ocupado && p == null ? 'Generando…' : 'Generar programación',
                icono: Icons.auto_awesome,
                ocupado: c.ocupado,
                alPresionar: c.generar,
              ),
              Tooltip(
                message: p == null
                    ? 'Genere una propuesta'
                    : p.estado != EstadoProgramacion.propuesta
                        ? 'La programación ya está ${p.estado.etiqueta.toLowerCase()}'
                        : p.phiValidador > 0
                            ? 'Resuelva los cruces antes de aprobar'
                            : 'Aprobar la propuesta',
                child: BotonAsincrono(
                  key: const Key('boton_aprobar'),
                  etiqueta: 'Aprobar',
                  icono: Icons.verified,
                  estilo: EstiloBoton.contorno,
                  ocupado: c.ocupado,
                  alPresionar: c.puedeAprobar ? c.aprobar : null,
                ),
              ),
            ],
          ),
          if (c.ocupado) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BannerError(mensaje: c.error, alCerrar: c.limpiarError),
              if (c.mensaje != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(c.mensaje!, key: const Key('mensaje_programacion'), style: TextStyle(color: esquema.primary)),
                ),
              if (p != null && p.phiValidador > 0)
                Material(
                  key: const Key('aviso_cruces'),
                  color: esquema.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber),
                    title: Text('Hay cruces sin resolver (Φ = ${p.phiValidador}): ajuste las asignaciones marcadas antes de aprobar'),
                  ),
                ),
              if (c.historial.length > 1) _Historial(c),
            ]),
          ),
          if (p == null)
            const Expanded(child: Center(child: Text('Aún no hay propuestas para este turno')))
          else ...[
            _Resumen(p),
            const TabBar(tabs: [
              Tab(icon: Icon(Icons.table_rows), text: 'Asignaciones'),
              Tab(icon: Icon(Icons.view_timeline), text: 'Gantt'),
              Tab(icon: Icon(Icons.show_chart), text: 'Convergencia'),
            ]),
            Expanded(
              child: TabBarView(children: [
                SingleChildScrollView(child: _TablaAsignaciones(c)),
                SingleChildScrollView(padding: const EdgeInsets.all(16), child: DiagramaGantt(asignaciones: c.asignaciones)),
                SingleChildScrollView(padding: const EdgeInsets.all(16), child: GraficoConvergencia(historial: p.historial)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Historial extends StatelessWidget {
  const _Historial(this.c);

  final ProgramacionControlador c;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Ejecuciones:'),
          for (final p in c.historial)
            ChoiceChip(
              label: Text('#${p.id} · ${p.estado.etiqueta} · ${hora(p.creadoEn.hour * 60 + p.creadoEn.minute)}'),
              selected: p.id == c.actual?.id,
              onSelected: (_) => c.abrir(p),
            ),
        ]),
      );
}

class _Resumen extends StatelessWidget {
  const _Resumen(this.p);

  final Programacion p;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final k = p.componentes;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IndicadorKpi(titulo: 'Estado', valor: p.estado.etiqueta, detalle: 'Programación #${p.id}'),
        IndicadorKpi(
          key: const Key('kpi_asignados'),
          titulo: 'Servicios asignados',
          valor: '${p.asignados} / ${p.asignaciones.length}',
          detalle: p.pendientes == 0 ? 'Sin incidencias' : '${p.pendientes} con incidencia',
          color: p.pendientes == 0 ? null : esquema.error,
        ),
        IndicadorKpi(
          key: const Key('kpi_phi'),
          titulo: 'Φ validador',
          valor: '${p.phiValidador}',
          detalle: 'Cruces y excesos',
          color: p.phiValidador == 0 ? esquema.primary : esquema.error,
        ),
        IndicadorKpi(titulo: 'Aptitud F(X)', valor: p.aptitud.toStringAsFixed(4), detalle: 'J = ${k.perdida.toStringAsFixed(4)}'),
        IndicadorKpi(titulo: 'Tiempo muerto', valor: '${k.tiempoMuertoMin} min', detalle: 'Retraso ${k.retrasoMin} min'),
        IndicadorKpi(titulo: 'Desequilibrio D', valor: '${k.desviacionCarga.toStringAsFixed(1)} min', detalle: '${k.reprogramados} reprogramados'),
        IndicadorKpi(
          titulo: p.metodo == AlgoritmoGenetico.identificador ? 'Algoritmo genético' : p.metodo,
          valor: '${(p.tiempoMs / 1000).toStringAsFixed(2)} s',
          detalle: '${p.generaciones} generaciones',
        ),
      ]),
    );
  }
}

class _TablaAsignaciones extends StatelessWidget {
  const _TablaAsignaciones(this.c);

  final ProgramacionControlador c;

  @override
  Widget build(BuildContext context) {
    final editable = c.actual?.estado == EstadoProgramacion.propuesta;
    return TablaDatos<Asignacion>(
      key: const Key('tabla_asignaciones'),
      filas: c.asignaciones,
      claveFila: (a) => ValueKey('asignacion_${a.codigoServicio}'),
      resaltar: (a) => a.estado != EstadoAsignacion.asignado,
      columnas: [
        ColumnaTabla('Servicio', (a) => Text(a.codigoServicio)),
        ColumnaTabla('Ruta', (a) => Text(a.codigoRuta)),
        ColumnaTabla('Prioridad', (a) => Text('${a.prioridad}')),
        ColumnaTabla('Vehículo', (a) => Text(a.codigoVehiculo ?? '—')),
        ColumnaTabla('Conductor', (a) => Text(a.codigoConductor ?? '—')),
        ColumnaTabla('Salida', (a) => Text(hora(a.salida))),
        ColumnaTabla('Término', (a) => Text(hora(a.fin))),
        ColumnaTabla('Estado', (a) => ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                a.motivo == null ? a.estado.etiqueta + (a.ajustada ? ' (ajustada)' : '') : '${a.estado.etiqueta}: ${a.motivo}',
              ),
            )),
        if (editable)
          ColumnaTabla('', (a) => IconButton(
                key: Key('ajustar_${a.codigoServicio}'),
                tooltip: 'Ajustar ${a.codigoServicio}',
                icon: const Icon(Icons.edit_calendar),
                onPressed: c.ocupado ? null : () => _ajustar(context, a),
              )),
      ],
    );
  }

  Future<void> _ajustar(BuildContext context, Asignacion a) async {
    final guardado = await DialogoFormulario.mostrar(context, controlador: c, constructor: () => _FormularioAjuste(a));
    if (guardado == true && context.mounted) mostrarAviso(context, c.mensaje ?? 'Ajuste registrado');
  }
}

class _FormularioAjuste extends StatefulWidget {
  const _FormularioAjuste(this.asignacion);

  final Asignacion asignacion;

  @override
  State<_FormularioAjuste> createState() => _FormularioAjusteState();
}

class _FormularioAjusteState extends State<_FormularioAjuste> {
  late int? _vehiculo = widget.asignacion.vehiculoId;
  late int? _conductor = widget.asignacion.conductorId;
  late final _salida = TextEditingController(text: widget.asignacion.salida == null ? '' : minutosAHora(widget.asignacion.salida!));

  @override
  void dispose() {
    _salida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<ProgramacionControlador>();
    final a = widget.asignacion;
    return DialogoFormulario<ProgramacionControlador>(
      titulo: 'Ajustar ${a.codigoServicio} (${a.codigoRuta})',
      claveGuardar: const Key('boton_guardar_ajuste'),
      alGuardar: () => c.ajustar(a, AjusteAsignacion(vehiculoId: _vehiculo!, conductorId: _conductor!, salida: horaAMinutos(_salida.text)!)),
      campos: (e) => [
        Text(
          'El ajuste debe ser una alternativa admisible: vehículo compatible con la ruta, conductor '
          'habilitado y en su turno, y una salida autorizada. El validador marca los cruces que genere.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        DropdownButtonFormField<int>(
          key: const Key('campo_vehiculo_ajuste'),
          initialValue: _vehiculo,
          decoration: InputDecoration(labelText: 'Vehículo', errorText: e['vehiculoId']),
          items: [
            for (final v in c.vehiculos)
              DropdownMenuItem(value: v.id, enabled: v.disponible, child: Text('${v.codigo} · ${v.capacidad} asientos${v.disponible ? '' : ' (no operativo)'}')),
          ],
          validator: (v) => v == null ? 'Seleccione un vehículo' : null,
          onChanged: (v) => setState(() => _vehiculo = v),
        ),
        DropdownButtonFormField<int>(
          key: const Key('campo_conductor_ajuste'),
          initialValue: _conductor,
          decoration: InputDecoration(labelText: 'Conductor', errorText: e['conductorId']),
          items: [for (final x in c.conductores) DropdownMenuItem(value: x.id, child: Text('${x.codigo} · ${x.nombreCompleto}'))],
          validator: (v) => v == null ? 'Seleccione un conductor' : null,
          onChanged: (v) => setState(() => _conductor = v),
        ),
        campoTexto(
          key: const Key('campo_salida_ajuste'),
          controlador: _salida,
          etiqueta: 'Hora de salida',
          ayuda: 'HH:MM, una salida autorizada de la ruta',
          errorServidor: e['salida'],
          validar: (t) => horaAMinutos(t) == null ? 'Hora HH:MM' : null,
        ),
      ],
    );
  }
}
