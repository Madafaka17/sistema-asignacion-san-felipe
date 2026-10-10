import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/operacion_controladores.dart';
import '../componentes/boton_asincrono.dart';
import '../componentes/indicador_kpi.dart';
import '../componentes/mensajes.dart';
import '../componentes/selector_fecha.dart';
import '../exportacion/exportador.dart';
import '../formato.dart';

/// HU-11: reporte de indicadores de un periodo (ecuaciones 19 a 23;
/// wireframe W-11).
class PantallaReportes extends StatelessWidget {
  const PantallaReportes({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReportesControlador>();
    final r = c.reporte;
    return ListView(
      children: [
        EncabezadoPantalla(
          titulo: 'Reporte de indicadores',
          descripcion: 'Desempeño de las programaciones aprobadas del periodo',
          acciones: [
            SelectorFecha(etiqueta: 'Desde', fecha: c.desde, alCambiar: (d) => c.cambiarPeriodo(d, c.hasta)),
            SelectorFecha(etiqueta: 'Hasta', fecha: c.hasta, alCambiar: (h) => c.cambiarPeriodo(c.desde, h)),
            BotonAsincrono(
              key: const Key('boton_generar_reporte'),
              etiqueta: 'Generar reporte',
              icono: Icons.insights,
              ocupado: c.ocupado,
              alPresionar: c.generar,
            ),
            BotonAsincrono(
              key: const Key('boton_exportar'),
              etiqueta: 'Exportar CSV',
              icono: Icons.download,
              estilo: EstiloBoton.contorno,
              ocupado: c.ocupado,
              alPresionar: r == null || r.sinDatos ? null : () => _exportar(context, c),
            ),
          ],
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerError(mensaje: c.error, alCerrar: c.limpiarError)),
        if (r == null)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Elija el periodo y genere el reporte')))
        else if (r.sinDatos)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(ReporteIndicadores.mensajeSinDatos, key: const Key('reporte_sin_datos'))),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(children: [
              IndicadorKpi(ancho: 204, titulo: 'Servicios programados', valor: '${r.serviciosProgramados}', detalle: '${r.programacionesGeneradas} ejecuciones del método'),
              IndicadorKpi(ancho: 204, key: const Key('kpi_pio'), titulo: 'PIO', valor: porcentaje(r.pio), detalle: 'Incidencias por recursos inadecuados (ec. 19)'),
              IndicadorKpi(ancho: 204, key: const Key('kpi_psr'), titulo: 'PSR', valor: porcentaje(r.psr), detalle: '${r.reprogramados} servicios reprogramados (ec. 20)'),
              IndicadorKpi(ancho: 204, key: const Key('kpi_psa'), titulo: 'PSA', valor: porcentaje(r.psa), detalle: '${r.conRetraso} servicios con retraso (ec. 21)'),
              IndicadorKpi(ancho: 204, titulo: 'PUV', valor: porcentaje(r.puv), detalle: 'Utilización de la flota (ec. 22)'),
              IndicadorKpi(ancho: 204, titulo: 'PAV', valor: porcentaje(r.pav), detalle: 'Asignaciones sin conflicto (ec. 23)'),
              IndicadorKpi(ancho: 204, titulo: 'D(X)', valor: '${r.desviacionCarga.toStringAsFixed(1)} min', detalle: 'Desviación de la carga de conductores'),
              IndicadorKpi(ancho: 204, titulo: 'Tiempo medio', valor: '${r.tiempoGeneracionPromedioS.toStringAsFixed(2)} s', detalle: 'Generación de la propuesta'),
            ]),
          ),
      ],
    );
  }

  Future<void> _exportar(BuildContext context, ReportesControlador c) async {
    final csv = await c.exportar();
    if (csv == null || !context.mounted) return;
    final ruta = await guardarArchivo('indicadores_${fechaATexto(c.desde)}_${fechaATexto(c.hasta)}.csv', csv, 'text/csv');
    if (context.mounted) mostrarAviso(context, 'Reporte exportado: $ruta');
  }
}
