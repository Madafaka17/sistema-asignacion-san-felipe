import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/operacion_controladores.dart';
import '../componentes/dialogo_formulario.dart';
import '../componentes/mensajes.dart';
import '../componentes/tabla_datos.dart';
import '../formato.dart';

/// HU-10: incidencias de la operación (wireframe W-10).
class PantallaIncidencias extends StatelessWidget {
  const PantallaIncidencias({super.key, this.editable = true});

  final bool editable;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<IncidenciasControlador>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoPantalla(
          titulo: 'Incidencias',
          descripcion: 'Retrasos, reprogramaciones e indisponibilidades registradas',
          acciones: [
            if (editable)
              FilledButton.icon(
                key: const Key('boton_nueva_incidencia'),
                icon: const Icon(Icons.add),
                label: const Text('Registrar incidencia'),
                onPressed: c.ocupado ? null : () => _abrir(context, c),
              ),
          ],
        ),
        if (c.ocupado) const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerError(mensaje: c.error, alCerrar: c.limpiarError)),
        Expanded(
          child: SingleChildScrollView(
            child: TablaDatos<Incidencia>(
              filas: c.incidencias,
              claveFila: (i) => ValueKey('incidencia_${i.id}'),
              columnas: [
                ColumnaTabla('Fecha', (i) => Text('${fechaCorta(i.fecha)} ${minutosAHora(i.hora)}')),
                ColumnaTabla('Servicio', (i) => Text(i.codigoServicio)),
                ColumnaTabla('Tipo', (i) => Text(i.tipo.etiqueta)),
                ColumnaTabla('Retraso', (i) => Text(i.minutosRetraso == null ? '—' : '${i.minutosRetraso} min'), numerica: true),
                ColumnaTabla('Vehículo', (i) => Text(i.codigoVehiculo ?? '—')),
                ColumnaTabla('Conductor', (i) => Text(i.codigoConductor ?? '—')),
                ColumnaTabla('Causa', (i) => Text(i.descripcion)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _abrir(BuildContext context, IncidenciasControlador c) async {
    final guardado = await DialogoFormulario.mostrar(context, controlador: c, constructor: () => const _FormularioIncidencia());
    if (guardado == true && context.mounted) mostrarAviso(context, 'Incidencia registrada');
  }
}

class _FormularioIncidencia extends StatefulWidget {
  const _FormularioIncidencia();

  @override
  State<_FormularioIncidencia> createState() => _FormularioIncidenciaState();
}

class _FormularioIncidenciaState extends State<_FormularioIncidencia> {
  final _servicio = TextEditingController();
  final _fecha = TextEditingController(text: fechaATexto(DateTime.now()));
  final _hora = TextEditingController();
  final _retraso = TextEditingController();
  final _descripcion = TextEditingController();
  TipoIncidencia _tipo = TipoIncidencia.retraso;

  @override
  void dispose() {
    for (final t in [_servicio, _fecha, _hora, _retraso, _descripcion]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<IncidenciasControlador>();
    final esRetraso = _tipo == TipoIncidencia.retraso;
    return DialogoFormulario<IncidenciasControlador>(
      titulo: 'Registrar incidencia',
      claveGuardar: const Key('boton_guardar_incidencia'),
      alGuardar: () => c.registrar(SolicitudIncidencia(
        codigoServicio: _servicio.text.trim().toUpperCase(),
        tipo: _tipo,
        fecha: intentarTextoAFecha(_fecha.text.trim())!,
        hora: horaAMinutos(_hora.text)!,
        minutosRetraso: esRetraso ? int.parse(_retraso.text.trim()) : null,
        descripcion: _descripcion.text.trim(),
      )),
      campos: (e) => [
        campoTexto(controlador: _servicio, etiqueta: 'Código del servicio', ayuda: 'Por ejemplo S-115', errorServidor: e['codigoServicio']),
        DropdownButtonFormField<TipoIncidencia>(
          initialValue: _tipo,
          decoration: InputDecoration(labelText: 'Tipo', errorText: e['tipo']),
          items: [for (final t in TipoIncidencia.values) DropdownMenuItem(value: t, child: Text(t.etiqueta))],
          onChanged: (v) => setState(() => _tipo = v ?? _tipo),
        ),
        Row(children: [
          Expanded(
            child: campoTexto(
              controlador: _fecha,
              etiqueta: 'Fecha',
              ayuda: 'AAAA-MM-DD',
              errorServidor: e['fecha'],
              validar: (t) => intentarTextoAFecha(t) == null ? 'Fecha AAAA-MM-DD' : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: campoTexto(
              controlador: _hora,
              etiqueta: 'Hora',
              ayuda: 'HH:MM',
              errorServidor: e['hora'],
              validar: (t) => horaAMinutos(t) == null ? 'Hora HH:MM' : null,
            ),
          ),
        ]),
        if (esRetraso)
          campoTexto(
            controlador: _retraso,
            etiqueta: 'Minutos de retraso',
            teclado: TextInputType.number,
            errorServidor: e['minutosRetraso'],
            validar: (t) => validarEntero(t, minimo: 1),
          ),
        campoTexto(controlador: _descripcion, etiqueta: 'Causa', errorServidor: e['descripcion']),
      ],
    );
  }
}
