import 'package:dominio/dominio.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/http_util.dart';
import '../servicios/registros_servicio.dart';

/// `/api/usuarios` (HU-01).
class UsuarioControlador {
  UsuarioControlador(this._servicio);

  final UsuarioServicio _servicio;

  void registrar(Router r) {
    r.get('/api/usuarios', (Request s) async {
      autorizar(s, Modulo.usuarios);
      return respuestaJson((await _servicio.listar(paginaConsulta(s))).toJson((u) => u.toJson()));
    });
    r.post('/api/usuarios', (Request s) async {
      final autor = autorizar(s, Modulo.usuarios, escritura: true);
      final solicitud = SolicitudUsuario.fromJson(await leerJson(s));
      return creado((await _servicio.crear(solicitud, autor)).toJson());
    });
  }
}

/// `/api/vehiculos` (HU-02).
class VehiculoControlador {
  VehiculoControlador(this._servicio);

  final VehiculoServicio _servicio;

  void registrar(Router r) {
    r.get('/api/vehiculos', (Request s) async {
      autorizar(s, Modulo.vehiculos);
      final estado = s.url.queryParameters['estado'];
      final pagina = await _servicio.listar(
        paginaConsulta(s),
        estado: estado == null ? null : EstadoVehiculo.values.where((e) => e.valor == estado).firstOrNull,
      );
      return respuestaJson(pagina.toJson((v) => v.toJson()));
    });
    r.get('/api/vehiculos/<id|[0-9]+>', (Request s) async {
      autorizar(s, Modulo.vehiculos);
      return respuestaJson((await _servicio.obtener(parametroEntero(s, 'id'))).toJson());
    });
    r.post('/api/vehiculos', (Request s) async {
      final autor = autorizar(s, Modulo.vehiculos, escritura: true);
      final vehiculo = Vehiculo.fromJson(await leerJson(s));
      return creado((await _servicio.crear(vehiculo, autor)).toJson());
    });
    r.put('/api/vehiculos/<id|[0-9]+>', (Request s) async {
      final autor = autorizar(s, Modulo.vehiculos, escritura: true);
      final vehiculo = Vehiculo.fromJson(await leerJson(s));
      return respuestaJson((await _servicio.actualizar(parametroEntero(s, 'id'), vehiculo, autor)).toJson());
    });
  }
}

/// `/api/conductores` (HU-03).
class ConductorControlador {
  ConductorControlador(this._servicio);

  final ConductorServicio _servicio;

  void registrar(Router r) {
    r.get('/api/conductores', (Request s) async {
      autorizar(s, Modulo.conductores);
      return respuestaJson((await _servicio.listar(paginaConsulta(s))).toJson((c) => c.toJson()));
    });
    r.get('/api/conductores/<id|[0-9]+>', (Request s) async {
      autorizar(s, Modulo.conductores);
      return respuestaJson((await _servicio.obtener(parametroEntero(s, 'id'))).toJson());
    });
    r.post('/api/conductores', (Request s) async {
      final autor = autorizar(s, Modulo.conductores, escritura: true);
      final conductor = Conductor.fromJson(await leerJson(s));
      return creado((await _servicio.crear(conductor, autor)).toJson());
    });
    r.put('/api/conductores/<id|[0-9]+>', (Request s) async {
      final autor = autorizar(s, Modulo.conductores, escritura: true);
      final conductor = Conductor.fromJson(await leerJson(s));
      return respuestaJson((await _servicio.actualizar(parametroEntero(s, 'id'), conductor, autor)).toJson());
    });
    r.put('/api/conductores/<id|[0-9]+>/disponibilidad', (Request s) async {
      final autor = autorizar(s, Modulo.conductores, escritura: true);
      final l = LectorJson(await leerJson(s));
      final disponible = l.booleano('disponible');
      l.verificar();
      return respuestaJson((await _servicio.cambiarDisponibilidad(parametroEntero(s, 'id'), disponible, autor)).toJson());
    });
  }
}

/// `/api/rutas` y `/api/salidas` (HU-04, HU-05).
class RutaControlador {
  RutaControlador(this._servicio);

  final RutaServicio _servicio;

  void registrar(Router r) {
    r.get('/api/rutas', (Request s) async {
      autorizar(s, Modulo.rutas);
      return respuestaJson([for (final ruta in await _servicio.listar()) ruta.toJson()]);
    });
    r.get('/api/rutas/<id|[0-9]+>', (Request s) async {
      autorizar(s, Modulo.rutas);
      return respuestaJson((await _servicio.obtener(parametroEntero(s, 'id'))).toJson());
    });
    r.post('/api/rutas', (Request s) async {
      final autor = autorizar(s, Modulo.rutas, escritura: true);
      final ruta = Ruta.fromJson(await leerJson(s));
      return creado((await _servicio.crear(ruta, autor)).toJson());
    });
    r.put('/api/rutas/<id|[0-9]+>', (Request s) async {
      final autor = autorizar(s, Modulo.rutas, escritura: true);
      final ruta = Ruta.fromJson(await leerJson(s));
      return respuestaJson((await _servicio.actualizar(parametroEntero(s, 'id'), ruta, autor)).toJson());
    });
    r.get('/api/rutas/<id|[0-9]+>/salidas', (Request s) async {
      autorizar(s, Modulo.rutas);
      return respuestaJson([for (final salida in await _servicio.salidas(parametroEntero(s, 'id'))) salida.toJson()]);
    });
    r.post('/api/rutas/<id|[0-9]+>/salidas', (Request s) async {
      final autor = autorizar(s, Modulo.rutas, escritura: true);
      final salida = SalidaAutorizada.fromJson(await leerJson(s));
      return creado((await _servicio.crearSalida(parametroEntero(s, 'id'), salida, autor)).toJson());
    });
    r.delete('/api/salidas/<id|[0-9]+>', (Request s) async {
      final autor = autorizar(s, Modulo.rutas, escritura: true);
      await _servicio.eliminarSalida(parametroEntero(s, 'id'), autor);
      return Response(204);
    });
  }
}

/// `/api/servicios` (HU-06).
class ServicioProgramadoControlador {
  ServicioProgramadoControlador(this._servicio);

  final ServicioProgramadoServicio _servicio;

  void registrar(Router r) {
    r.get('/api/servicios', (Request s) async {
      autorizar(s, Modulo.servicios);
      final estado = s.url.queryParameters['estado'];
      final pagina = await _servicio.listar(
        paginaConsulta(s),
        fecha: fechaConsulta(s, 'fecha'),
        estado: estado == null ? null : EstadoServicio.values.where((e) => e.valor == estado).firstOrNull,
      );
      return respuestaJson(pagina.toJson((sv) => sv.toJson()));
    });
    r.get('/api/servicios/<id|[0-9]+>', (Request s) async {
      autorizar(s, Modulo.servicios);
      return respuestaJson((await _servicio.obtener(parametroEntero(s, 'id'))).toJson());
    });
    r.post('/api/servicios', (Request s) async {
      final autor = autorizar(s, Modulo.servicios, escritura: true);
      final servicio = ServicioProgramado.fromJson(await leerJson(s));
      return creado((await _servicio.crear(servicio, autor)).toJson());
    });
    r.put('/api/servicios/<id|[0-9]+>', (Request s) async {
      final autor = autorizar(s, Modulo.servicios, escritura: true);
      final servicio = ServicioProgramado.fromJson(await leerJson(s));
      return respuestaJson((await _servicio.actualizar(parametroEntero(s, 'id'), servicio, autor)).toJson());
    });
    r.post('/api/servicios/<id|[0-9]+>/cancelar', (Request s) async {
      final autor = autorizar(s, Modulo.servicios, escritura: true);
      return respuestaJson((await _servicio.cancelar(parametroEntero(s, 'id'), autor)).toJson());
    });
  }
}
