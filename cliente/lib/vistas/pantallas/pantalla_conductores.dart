import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/registros_controladores.dart';
import '../componentes/dialogo_formulario.dart';
import '../componentes/mensajes.dart';
import '../componentes/tabla_datos.dart';
import '../formato.dart';

/// HU-03: conductores con su licencia, turno y horas acumuladas
/// (wireframe W-03).
class PantallaConductores extends StatelessWidget {
  const PantallaConductores({super.key, this.editable = true, this.hoy});

  final bool editable;

  /// Fecha para evaluar la vigencia de las licencias (pruebas).
  final DateTime? hoy;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConductoresControlador>();
    final fecha = soloFecha(hoy ?? DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoPantalla(
          titulo: 'Conductores',
          descripcion: '${c.conductores.where((x) => x.disponible && x.licenciaVigente(fecha)).length} habilitados',
          acciones: [
            if (editable)
              FilledButton.icon(
                key: const Key('boton_nuevo_conductor'),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo conductor'),
                onPressed: c.ocupado ? null : () => _abrir(context, c, null),
              ),
          ],
        ),
        if (c.ocupado) const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerError(mensaje: c.error, alCerrar: c.limpiarError)),
        Expanded(
          child: SingleChildScrollView(
            child: TablaDatos<Conductor>(
              filas: c.conductores,
              claveFila: (x) => ValueKey('conductor_${x.codigo}'),
              resaltar: (x) => !x.licenciaVigente(fecha),
              columnas: [
                ColumnaTabla('Código', (x) => Text(x.codigo)),
                ColumnaTabla('Nombre', (x) => Text(x.nombreCompleto)),
                ColumnaTabla('Licencia', (x) => Text(x.categoriaLicencia.valor)),
                ColumnaTabla('Vence', (x) => Text(
                      x.licenciaVigente(fecha) ? fechaCorta(x.vencimientoLicencia) : '${fechaCorta(x.vencimientoLicencia)} (vencida)',
                    )),
                ColumnaTabla('Turno', (x) => Text('${minutosAHora(x.turnoInicio)}–${minutosAHora(x.turnoFin)}')),
                ColumnaTabla('Acumulado / límite', (x) => Text('${x.minutosAcumulados} / ${x.limiteMinutos} min'), numerica: true),
                ColumnaTabla('Disponible', (x) => Switch(
                      value: x.disponible,
                      onChanged: editable && !c.ocupado ? (v) => c.cambiarDisponibilidad(x, v) : null,
                    )),
                if (editable)
                  ColumnaTabla('', (x) => IconButton(
                        tooltip: 'Editar ${x.codigo}',
                        icon: const Icon(Icons.edit),
                        onPressed: c.ocupado ? null : () => _abrir(context, c, x),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _abrir(BuildContext context, ConductoresControlador c, Conductor? conductor) async {
    final guardado = await DialogoFormulario.mostrar(context, controlador: c, constructor: () => _FormularioConductor(conductor));
    if (guardado == true && context.mounted) mostrarAviso(context, 'Conductor guardado');
  }
}

class _FormularioConductor extends StatefulWidget {
  const _FormularioConductor(this.conductor);

  final Conductor? conductor;

  @override
  State<_FormularioConductor> createState() => _FormularioConductorState();
}

class _FormularioConductorState extends State<_FormularioConductor> {
  late final Conductor? _c = widget.conductor;
  late final _codigo = TextEditingController(text: _c?.codigo);
  late final _dni = TextEditingController(text: _c?.dni);
  late final _nombres = TextEditingController(text: _c?.nombres);
  late final _apellidos = TextEditingController(text: _c?.apellidos);
  late final _vence = TextEditingController(text: _c == null ? '' : fechaATexto(_c.vencimientoLicencia));
  late final _inicio = TextEditingController(text: minutosAHora(_c?.turnoInicio ?? 360));
  late final _fin = TextEditingController(text: minutosAHora(_c?.turnoFin ?? 960));
  late final _acumulados = TextEditingController(text: '${_c?.minutosAcumulados ?? 0}');
  late final _limite = TextEditingController(text: '${_c?.limiteMinutos ?? 600}');
  late CategoriaLicencia _licencia = _c?.categoriaLicencia ?? CategoriaLicencia.aIIb;
  late bool _disponible = _c?.disponible ?? true;

  @override
  void dispose() {
    for (final t in [_codigo, _dni, _nombres, _apellidos, _vence, _inicio, _fin, _acumulados, _limite]) {
      t.dispose();
    }
    super.dispose();
  }

  String? _validarHora(String t) => horaAMinutos(t) == null ? 'Hora HH:MM' : null;

  @override
  Widget build(BuildContext context) {
    final c = context.read<ConductoresControlador>();
    return DialogoFormulario<ConductoresControlador>(
      titulo: _c == null ? 'Nuevo conductor' : 'Editar ${_c.codigo}',
      claveGuardar: const Key('boton_guardar_conductor'),
      alGuardar: () => c.guardar(Conductor(
        id: _c?.id ?? 0,
        codigo: _codigo.text.trim().toUpperCase(),
        dni: _dni.text.trim(),
        nombres: _nombres.text.trim(),
        apellidos: _apellidos.text.trim(),
        categoriaLicencia: _licencia,
        vencimientoLicencia: intentarTextoAFecha(_vence.text.trim())!,
        turnoInicio: horaAMinutos(_inicio.text)!,
        turnoFin: horaAMinutos(_fin.text)!,
        minutosAcumulados: int.parse(_acumulados.text.trim()),
        limiteMinutos: int.parse(_limite.text.trim()),
        disponible: _disponible,
      )),
      campos: (e) => [
        campoTexto(controlador: _codigo, etiqueta: 'Código', ayuda: 'Por ejemplo C-12', errorServidor: e['codigo']),
        campoTexto(
          controlador: _dni,
          etiqueta: 'DNI',
          teclado: TextInputType.number,
          errorServidor: e['dni'],
          validar: (t) => Conductor.formatoDni.hasMatch(t) ? null : 'El DNI debe tener 8 dígitos',
        ),
        campoTexto(controlador: _nombres, etiqueta: 'Nombres', errorServidor: e['nombres']),
        campoTexto(controlador: _apellidos, etiqueta: 'Apellidos', errorServidor: e['apellidos']),
        DropdownButtonFormField<CategoriaLicencia>(
          initialValue: _licencia,
          decoration: InputDecoration(labelText: 'Categoría de licencia', errorText: e['categoriaLicencia']),
          items: [for (final k in CategoriaLicencia.values) DropdownMenuItem(value: k, child: Text(k.valor))],
          onChanged: (v) => setState(() => _licencia = v ?? _licencia),
        ),
        campoTexto(
          controlador: _vence,
          etiqueta: 'Vencimiento de la licencia',
          ayuda: 'AAAA-MM-DD',
          errorServidor: e['vencimientoLicencia'],
          validar: (t) => intentarTextoAFecha(t) == null ? 'Fecha AAAA-MM-DD' : null,
        ),
        Row(children: [
          Expanded(child: campoTexto(controlador: _inicio, etiqueta: 'Inicio de turno', validar: _validarHora, errorServidor: e['turnoInicio'])),
          const SizedBox(width: 12),
          Expanded(child: campoTexto(controlador: _fin, etiqueta: 'Fin de turno', validar: _validarHora, errorServidor: e['turnoFin'])),
        ]),
        Row(children: [
          Expanded(
            child: campoTexto(
              controlador: _acumulados,
              etiqueta: 'Minutos acumulados (H_c0)',
              teclado: TextInputType.number,
              validar: (t) => validarEntero(t),
              errorServidor: e['minutosAcumulados'],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: campoTexto(
              controlador: _limite,
              etiqueta: 'Límite (H_cmáx, min)',
              teclado: TextInputType.number,
              validar: (t) => validarEntero(t, minimo: 1),
              errorServidor: e['limiteMinutos'],
            ),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Disponible'),
          value: _disponible,
          onChanged: (v) => setState(() => _disponible = v),
        ),
      ],
    );
  }
}
