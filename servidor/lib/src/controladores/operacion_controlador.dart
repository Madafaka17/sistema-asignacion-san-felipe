import 'package:dominio/dominio.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/http_util.dart';
import '../servicios/operacion_servicio.dart';
import '../servicios/programacion_servicio.dart';
import '../servicios/registros_servicio.dart';

/// `/api/programaciones` (HU-07, HU-08, HU-09).
class ProgramacionControlador {
  ProgramacionControlador(this._servicio);

  final ProgramacionServicio _servicio;

  void registrar(Router r) {
    r.post('/api/programaciones', (Request s) async {
      final usuario = autorizar(s, Modulo.programacion, escritura: true);
      final solicitud = SolicitudProgramacion.fromJson(await leerJson(s));
      return creado((await _servicio.generar(solicitud.fecha, usuario)).toJson());
    });
    r.get('/api/programaciones', (Request s) async {
      autorizar(s, Modulo.programacion);
      return respuestaJson([for (final p in await _servicio.listar(fecha: fechaConsulta(s, 'fecha'))) p.toJson()]);
    });
    r.get('/api/programaciones/<id|[0-9]+>', (Request s) async {
      autorizar(s, Modulo.programacion);
      return respuestaJson((await _servicio.obtener(parametroEntero(s, 'id'))).toJson());
    });
    r.put('/api/programaciones/<id|[0-9]+>/asignaciones/<servicio|[0-9]+>', (Request s) async {
      final usuario = autorizar(s, Modulo.programacion, escritura: true);
      final ajuste = AjusteAsignacion.fromJson(await leerJson(s));
      final programacion = await _servicio.ajustar(
        parametroEntero(s, 'id'),
        parametroEntero(s, 'servicio'),
        ajuste,
        usuario,
      );
      return respuestaJson(programacion.toJson());
    });
    r.post('/api/programaciones/<id|[0-9]+>/aprobar', (Request s) async {
      final usuario = autorizar(s, Modulo.programacion, escritura: true);
      return respuestaJson((await _servicio.aprobar(parametroEntero(s, 'id'), usuario)).toJson());
    });
  }
}

/// `/api/incidencias` (HU-10).
class IncidenciaControlador {
  IncidenciaControlador(this._servicio);

  final IncidenciaServicio _servicio;

  void registrar(Router r) {
    r.get('/api/incidencias', (Request s) async {
      autorizar(s, Modulo.incidencias);
      final pagina = await _servicio.listar(
        paginaConsulta(s),
        desde: fechaConsulta(s, 'desde'),
        hasta: fechaConsulta(s, 'hasta'),
      );
      return respuestaJson(pagina.toJson((i) => i.toJson()));
    });
    r.post('/api/incidencias', (Request s) async {
      final usuario = autorizar(s, Modulo.incidencias, escritura: true);
      final solicitud = SolicitudIncidencia.fromJson(await leerJson(s));
      return creado((await _servicio.registrar(solicitud, usuario)).toJson());
    });
  }
}

/// `/api/reportes`, `/api/bitacora` y `/api/parametros` (HU-11, sección 3.6).
class ReporteControlador {
  ReporteControlador(this._reportes, this._bitacora, this._parametros);

  final ReporteServicio _reportes;
  final BitacoraServicio _bitacora;
  final ParametrosServicio _parametros;

  void registrar(Router r) {
    r.get('/api/reportes/indicadores', (Request s) async {
      autorizar(s, Modulo.reportes);
      final reporte = await _reportes.indicadores(
        fechaConsulta(s, 'desde', obligatoria: true)!,
        fechaConsulta(s, 'hasta', obligatoria: true)!,
      );
      return respuestaJson(reporte.toJson());
    });
    r.get('/api/reportes/indicadores.csv', (Request s) async {
      autorizar(s, Modulo.reportes);
      final desde = fechaConsulta(s, 'desde', obligatoria: true)!;
      final hasta = fechaConsulta(s, 'hasta', obligatoria: true)!;
      return Response.ok(
        await _reportes.csv(desde, hasta),
        headers: {
          'content-type': 'text/csv; charset=utf-8',
          'content-disposition': 'attachment; filename="indicadores_${fechaATexto(desde)}_${fechaATexto(hasta)}.csv"',
        },
      );
    });
    r.get('/api/bitacora', (Request s) async {
      autorizar(s, Modulo.bitacora);
      final q = s.url.queryParameters;
      final pagina = await _bitacora.listar(
        paginaConsulta(s),
        accion: q['accion'],
        entidad: q['entidad'],
        entidadId: int.tryParse(q['entidadId'] ?? ''),
      );
      return respuestaJson(pagina.toJson((e) => e.toJson()));
    });
    r.get('/api/parametros', (Request s) async {
      autorizar(s, Modulo.parametros);
      return respuestaJson(_parametros.vigentes());
    });
  }
}
