import 'package:dominio/dominio.dart';

import '../configuracion/parametros_sistema.dart';
import '../infraestructura/base_datos.dart';
import '../infraestructura/reloj.dart';
import '../repositorios/repositorio_bitacora.dart';
import '../repositorios/repositorio_incidencias.dart';
import '../repositorios/repositorio_programaciones.dart';
import '../repositorios/repositorio_reportes.dart';
import '../repositorios/repositorio_servicios.dart';
import '../seguridad/tokens.dart';
import 'registros_servicio.dart';

/// HU-10: incidencias de la operación.
class IncidenciaServicio {
  IncidenciaServicio({
    required this.bd,
    required this.incidencias,
    required this.servicios,
    required this.programaciones,
    required this.bitacora,
    required this.reloj,
  });

  final BaseDatos bd;
  final RepositorioIncidencias incidencias;
  final RepositorioServicios servicios;
  final RepositorioProgramaciones programaciones;
  final RepositorioBitacora bitacora;
  final Reloj reloj;

  Future<Pagina<Incidencia>> listar(ParametrosPagina pagina, {DateTime? desde, DateTime? hasta}) =>
      incidencias.listar(pagina, desde: desde, hasta: hasta);

  /// Registra la incidencia y la asocia al vehículo y al conductor de la
  /// asignación aprobada del servicio. Una indisponibilidad devuelve el
  /// servicio a pendiente para que se reprograme.
  Future<Incidencia> registrar(SolicitudIncidencia solicitud, UsuarioAutenticado usuario) async {
    final servicio = await servicios.buscarPorCodigo(solicitud.codigoServicio) ??
        (throw ExcepcionApi(CodigoError.noEncontrado, 'Servicio no encontrado', campos: {'codigoServicio': 'Servicio no encontrado'}));
    if (!esMinutoDelDia(solicitud.hora)) reglaIncumplida('hora', 'La hora debe estar entre 00:00 y 23:59');
    if (solicitud.tipo == TipoIncidencia.retraso && (solicitud.minutosRetraso ?? 0) <= 0) {
      reglaIncumplida('minutosRetraso', 'Indique los minutos de retraso');
    }
    final aprobada = await programaciones.aprobadaDe(servicio.fecha);
    final asignacion = aprobada?.asignaciones
        .where((a) => a.servicioId == servicio.id && a.tieneRecursos)
        .firstOrNull;

    final id = await bd.transaccion((tx) async {
      final id = await incidencias.crear(
        tx,
        NuevaIncidencia(
          servicioId: servicio.id,
          tipo: solicitud.tipo,
          fecha: solicitud.fecha,
          hora: solicitud.hora,
          minutosRetraso: solicitud.tipo == TipoIncidencia.retraso ? solicitud.minutosRetraso : null,
          descripcion: solicitud.descripcion,
          vehiculoId: asignacion?.vehiculoId,
          conductorId: asignacion?.conductorId,
          registradoPor: usuario.id,
        ),
      );
      if (solicitud.tipo.requiereReprogramar && servicio.estado == EstadoServicio.programado) {
        await servicios.cambiarEstado(tx, [servicio.id], EstadoServicio.pendiente);
      }
      await bitacora.registrar(
        tx,
        usuarioId: usuario.id,
        accion: 'registrar_incidencia',
        entidad: 'incidencia',
        entidadId: id,
        detalle: {'servicio': servicio.codigo, 'tipo': solicitud.tipo.valor},
        fechaHora: reloj.ahora(),
      );
      return id;
    });
    return (await incidencias.buscar(id))!;
  }
}

/// HU-11: reporte de indicadores de un periodo (ecuaciones 19 a 23).
class ReporteServicio {
  ReporteServicio({required this.reportes, required this.parametros});

  final RepositorioReportes reportes;
  final ParametrosSistema parametros;

  Future<ReporteIndicadores> indicadores(DateTime desde, DateTime hasta) async {
    if (hasta.isBefore(desde)) reglaIncumplida('hasta', 'La fecha final debe ser posterior a la inicial');
    final d = await reportes.datos(desde, hasta, minutosDisponiblesVehiculo: parametros.minutosDisponiblesVehiculo);
    if (d.programacionesAprobadas == 0) return ReporteIndicadores.vacio(desde, hasta);
    int incidencias(TipoIncidencia tipo) => d.incidenciasPorTipo[tipo.valor] ?? 0;
    final vehiculos = incidencias(TipoIncidencia.indisponibilidadVehiculo);
    final conductores = incidencias(TipoIncidencia.indisponibilidadConductor);
    final reprogramados = incidencias(TipoIncidencia.reprogramacion);
    final conRetraso = incidencias(TipoIncidencia.retraso);
    return ReporteIndicadores(
      desde: desde,
      hasta: hasta,
      serviciosProgramados: d.serviciosProgramados,
      reprogramados: reprogramados,
      conRetraso: conRetraso,
      vehiculosInadecuados: vehiculos,
      conductoresInadecuados: conductores,
      pio: Indicadores.pio(vehiculos, conductores, d.serviciosProgramados),
      psr: Indicadores.psr(reprogramados, d.serviciosProgramados),
      psa: Indicadores.psa(conRetraso, d.serviciosProgramados),
      puv: Indicadores.puv(d.minutosServicio, d.minutosDisponibles),
      pav: Indicadores.pav(d.asignacionesSinConflicto, d.asignacionesGeneradas),
      desviacionCarga: d.desviacionPromedio,
      tiempoGeneracionPromedioS: d.tiempoGeneracionPromedioMs / 1000,
      programacionesGeneradas: d.programacionesGeneradas,
    );
  }

  /// Reporte exportable en CSV (separado por punto y coma, como lo abre
  /// Excel en configuración regional de Perú).
  Future<String> csv(DateTime desde, DateTime hasta) async {
    final r = await indicadores(desde, hasta);
    String p(double v) => Indicadores.redondear(v).toStringAsFixed(1);
    final filas = [
      ['Indicador', 'Valor', 'Unidad'],
      ['Periodo', '${fechaATexto(r.desde)} a ${fechaATexto(r.hasta)}', ''],
      if (r.sinDatos) [ReporteIndicadores.mensajeSinDatos, '', ''],
      if (!r.sinDatos) ...[
        ['Servicios programados', '${r.serviciosProgramados}', 'servicios'],
        ['Porcentaje de incidencias operativas (PIO)', p(r.pio), '%'],
        ['Porcentaje de servicios reprogramados (PSR)', p(r.psr), '%'],
        ['Porcentaje de servicios con retraso (PSA)', p(r.psa), '%'],
        ['Porcentaje de utilización de vehículos (PUV)', p(r.puv), '%'],
        ['Porcentaje de asignaciones válidas (PAV)', p(r.pav), '%'],
        ['Equilibrio de la carga laboral D(X)', r.desviacionCarga.toStringAsFixed(1), 'min'],
        ['Tiempo medio de generación', r.tiempoGeneracionPromedioS.toStringAsFixed(3), 's'],
      ],
    ];
    return '${filas.map((f) => f.map(_celda).join(';')).join('\r\n')}\r\n';
  }

  static String _celda(String valor) =>
      valor.contains(RegExp(r'[;"\r\n]')) ? '"${valor.replaceAll('"', '""')}"' : valor;
}

class BitacoraServicio {
  const BitacoraServicio(this.bitacora);

  final RepositorioBitacora bitacora;

  Future<Pagina<EntradaBitacora>> listar(ParametrosPagina pagina, {String? accion, String? entidad, int? entidadId}) =>
      bitacora.listar(pagina, accion: accion, entidad: entidad, entidadId: entidadId);
}
