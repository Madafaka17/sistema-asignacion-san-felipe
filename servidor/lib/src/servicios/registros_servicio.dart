import 'package:dominio/dominio.dart';

import '../configuracion/parametros_sistema.dart';
import '../infraestructura/base_datos.dart';
import '../infraestructura/reloj.dart';
import '../repositorios/repositorio_bitacora.dart';
import '../repositorios/repositorio_conductores.dart';
import '../repositorios/repositorio_rutas.dart';
import '../repositorios/repositorio_servicios.dart';
import '../repositorios/repositorio_usuarios.dart';
import '../repositorios/repositorio_vehiculos.dart';
import '../seguridad/contrasenas.dart';
import '../seguridad/tokens.dart';

/// Lanza un error de regla de negocio (HTTP 422) asociado a un campo.
Never reglaIncumplida(String campo, String mensaje) =>
    throw ExcepcionApi(CodigoError.reglaNegocio, mensaje, campos: {campo: mensaje});

Never duplicado(String campo, String mensaje) =>
    throw ExcepcionApi(CodigoError.conflicto, mensaje, campos: {campo: mensaje});

Never noEncontrado(String mensaje) => throw ExcepcionApi(CodigoError.noEncontrado, mensaje);

/// Base común: registra los cambios de datos en la bitácora (sección 3.6).
abstract class ServicioConBitacora {
  ServicioConBitacora({required this.bd, required this.bitacora, required this.reloj});

  final Ejecutor bd;
  final RepositorioBitacora bitacora;
  final Reloj reloj;

  Future<void> registrar(UsuarioAutenticado usuario, String accion, String entidad, int id, [Map<String, Object?> detalle = const {}]) =>
      bitacora.registrar(
        bd,
        usuarioId: usuario.id,
        accion: accion,
        entidad: entidad,
        entidadId: id,
        detalle: detalle,
        fechaHora: reloj.ahora(),
      );
}

/// HU-01: registro de usuarios con su rol.
class UsuarioServicio extends ServicioConBitacora {
  UsuarioServicio({
    required super.bd,
    required super.bitacora,
    required super.reloj,
    required this.usuarios,
    required this.contrasenas,
  });

  final RepositorioUsuarios usuarios;
  final Contrasenas contrasenas;

  static final _formatoNombre = RegExp(r'^[a-z0-9._]{4,50}$');

  Future<Pagina<Usuario>> listar(ParametrosPagina pagina) => usuarios.listar(pagina);

  Future<Usuario> crear(SolicitudUsuario solicitud, UsuarioAutenticado autor) async {
    final nombre = solicitud.nombreUsuario.toLowerCase();
    if (!_formatoNombre.hasMatch(nombre)) {
      reglaIncumplida('nombreUsuario', 'De 4 a 50 caracteres: letras minúsculas, dígitos, punto o guion bajo');
    }
    final debilidad = Contrasenas.validarFortaleza(solicitud.contrasena);
    if (debilidad != null) reglaIncumplida('contrasena', debilidad);
    if (await usuarios.existeNombre(nombre)) duplicado('nombreUsuario', 'El nombre de usuario ya existe');
    final id = await usuarios.crear(
      SolicitudUsuario(
        nombreUsuario: nombre,
        nombreCompleto: solicitud.nombreCompleto,
        rol: solicitud.rol,
        contrasena: solicitud.contrasena,
      ),
      contrasenas.resumir(solicitud.contrasena),
    );
    await registrar(autor, 'crear_usuario', 'usuario', id, {'nombreUsuario': nombre, 'rol': solicitud.rol.valor});
    return (await usuarios.buscar(id))!;
  }
}

/// HU-02: registro de vehículos.
class VehiculoServicio extends ServicioConBitacora {
  VehiculoServicio({required super.bd, required super.bitacora, required super.reloj, required this.vehiculos});

  final RepositorioVehiculos vehiculos;

  Future<Pagina<Vehiculo>> listar(ParametrosPagina pagina, {EstadoVehiculo? estado}) =>
      vehiculos.listar(pagina, estado: estado);

  Future<Vehiculo> obtener(int id) async => await vehiculos.buscar(id) ?? noEncontrado('Vehículo no encontrado');

  Future<Vehiculo> crear(Vehiculo vehiculo, UsuarioAutenticado autor) async {
    await _validar(vehiculo);
    final id = await vehiculos.crear(vehiculo);
    await registrar(autor, 'crear_vehiculo', 'vehiculo', id, vehiculo.toJson()..remove('id'));
    return obtener(id);
  }

  Future<Vehiculo> actualizar(int id, Vehiculo vehiculo, UsuarioAutenticado autor) async {
    final anterior = await obtener(id);
    final nuevo = vehiculo.copiarCon(id: id);
    await _validar(nuevo, excepto: id);
    await vehiculos.actualizar(nuevo);
    await registrar(autor, 'actualizar_vehiculo', 'vehiculo', id, {'antes': anterior.toJson(), 'despues': nuevo.toJson()});
    return obtener(id);
  }

  Future<void> _validar(Vehiculo v, {int? excepto}) async {
    if (!Vehiculo.formatoPlaca.hasMatch(v.placa)) reglaIncumplida('placa', 'Formato de placa inválido (ABC-123)');
    if (v.capacidad < 1 || v.capacidad > 100) reglaIncumplida('capacidad', 'La capacidad debe estar entre 1 y 100 asientos');
    if (await vehiculos.existePlaca(v.placa, excepto: excepto)) duplicado('placa', 'La placa ya está registrada');
    if (await vehiculos.existeCodigo(v.codigo, excepto: excepto)) duplicado('codigo', 'El código de unidad ya está registrado');
  }
}

/// HU-03: registro de conductores, su licencia, turno y horas acumuladas.
class ConductorServicio extends ServicioConBitacora {
  ConductorServicio({required super.bd, required super.bitacora, required super.reloj, required this.conductores});

  final RepositorioConductores conductores;

  Future<Pagina<Conductor>> listar(ParametrosPagina pagina) => conductores.listar(pagina);

  Future<Conductor> obtener(int id) async => await conductores.buscar(id) ?? noEncontrado('Conductor no encontrado');

  Future<Conductor> crear(Conductor conductor, UsuarioAutenticado autor) async {
    await _validar(conductor);
    final id = await conductores.crear(conductor);
    await registrar(autor, 'crear_conductor', 'conductor', id, {'codigo': conductor.codigo});
    return obtener(id);
  }

  Future<Conductor> actualizar(int id, Conductor conductor, UsuarioAutenticado autor) async {
    final anterior = await obtener(id);
    final nuevo = conductor.copiarCon(id: id);
    await _validar(nuevo, excepto: id);
    await conductores.actualizar(nuevo);
    await registrar(autor, 'actualizar_conductor', 'conductor', id, {'antes': anterior.toJson(), 'despues': nuevo.toJson()});
    return obtener(id);
  }

  /// Marca al conductor como disponible o no. No puede marcarse disponible a
  /// un conductor con la licencia vencida (HU-03, escenario de error).
  Future<Conductor> cambiarDisponibilidad(int id, bool disponible, UsuarioAutenticado autor) async {
    final conductor = await obtener(id);
    if (disponible && !conductor.licenciaVigente(reloj.ahora())) {
      reglaIncumplida('vencimientoLicencia', 'Licencia vencida');
    }
    await conductores.cambiarDisponibilidad(id, disponible);
    await registrar(autor, 'cambiar_disponibilidad', 'conductor', id, {'disponible': disponible});
    return obtener(id);
  }

  Future<void> _validar(Conductor c, {int? excepto}) async {
    if (!Conductor.formatoDni.hasMatch(c.dni)) reglaIncumplida('dni', 'El DNI debe tener 8 dígitos');
    if (c.turnoInicio < 0 || c.turnoFin > minutosPorDia || c.turnoInicio >= c.turnoFin) {
      reglaIncumplida('turnoFin', 'El turno debe terminar después de iniciar, dentro del día');
    }
    if (c.limiteMinutos <= 0) reglaIncumplida('limiteMinutos', 'El límite de conducción debe ser mayor que cero');
    if (c.minutosAcumulados < 0) reglaIncumplida('minutosAcumulados', 'Los minutos acumulados no pueden ser negativos');
    if (c.disponible && !c.licenciaVigente(reloj.ahora())) reglaIncumplida('vencimientoLicencia', 'Licencia vencida');
    if (await conductores.existeCodigo(c.codigo, excepto: excepto)) duplicado('codigo', 'El código de conductor ya está registrado');
    if (await conductores.existeDni(c.dni, excepto: excepto)) duplicado('dni', 'El DNI ya está registrado');
  }
}

/// HU-04 y HU-05: rutas autorizadas, su compatibilidad y sus salidas.
class RutaServicio extends ServicioConBitacora {
  RutaServicio({
    required super.bd,
    required super.bitacora,
    required super.reloj,
    required this.rutas,
    required this.vehiculos,
  });

  final RepositorioRutas rutas;
  final RepositorioVehiculos vehiculos;

  Future<List<Ruta>> listar() => rutas.todas();

  Future<Ruta> obtener(int id) async => await rutas.buscar(id) ?? noEncontrado('Ruta no encontrada');

  Future<Ruta> crear(Ruta ruta, UsuarioAutenticado autor) async {
    await _validar(ruta);
    final id = await rutas.crear(ruta);
    await registrar(autor, 'crear_ruta', 'ruta', id, ruta.toJson()..remove('id'));
    return obtener(id);
  }

  Future<Ruta> actualizar(int id, Ruta ruta, UsuarioAutenticado autor) async {
    final anterior = await obtener(id);
    final nueva = Ruta(
      id: id,
      codigo: ruta.codigo,
      origen: ruta.origen,
      destino: ruta.destino,
      duracionMin: ruta.duracionMin,
      activa: ruta.activa,
      vehiculosCompatibles: ruta.vehiculosCompatibles,
    );
    await _validar(nueva, excepto: id);
    await rutas.actualizar(nueva);
    await registrar(autor, 'actualizar_ruta', 'ruta', id, {'antes': anterior.toJson(), 'despues': nueva.toJson()});
    return obtener(id);
  }

  Future<List<SalidaAutorizada>> salidas(int rutaId) async {
    await obtener(rutaId);
    return rutas.salidas(rutaId: rutaId);
  }

  Future<SalidaAutorizada> crearSalida(int rutaId, SalidaAutorizada salida, UsuarioAutenticado autor) async {
    await obtener(rutaId);
    if (!esMinutoDelDia(salida.hora)) reglaIncumplida('hora', 'La hora debe estar entre 00:00 y 23:59');
    if (salida.duracionMin != null && salida.duracionMin! <= 0) {
      reglaIncumplida('duracionMin', 'La duración debe ser mayor que cero');
    }
    if (await rutas.existeSalida(rutaId, salida.hora)) duplicado('hora', 'La salida ya existe para esta ruta');
    final id = await rutas.crearSalida(SalidaAutorizada(rutaId: rutaId, hora: salida.hora, duracionMin: salida.duracionMin));
    await registrar(autor, 'crear_salida', 'salida_autorizada', id, {'rutaId': rutaId, 'hora': minutosAHora(salida.hora)});
    return (await rutas.buscarSalida(id))!;
  }

  Future<void> eliminarSalida(int id, UsuarioAutenticado autor) async {
    final salida = await rutas.buscarSalida(id) ?? noEncontrado('Salida no encontrada');
    if (await rutas.salidaEnUso(salida)) {
      throw ExcepcionApi(CodigoError.conflicto, 'La salida tiene servicios registrados y no puede eliminarse');
    }
    await rutas.eliminarSalida(id);
    await registrar(autor, 'eliminar_salida', 'salida_autorizada', id, {'rutaId': salida.rutaId, 'hora': minutosAHora(salida.hora)});
  }

  Future<void> _validar(Ruta r, {int? excepto}) async {
    if (r.duracionMin <= 0) reglaIncumplida('duracionMin', 'La duración debe ser mayor que cero');
    if (r.duracionMin >= minutosPorDia) reglaIncumplida('duracionMin', 'La duración debe ser menor de 24 horas');
    final existentes = {for (final v in await vehiculos.todos()) v.id};
    if (!existentes.containsAll(r.vehiculosCompatibles)) {
      reglaIncumplida('vehiculosCompatibles', 'Algún vehículo compatible no existe');
    }
    if (await rutas.existeCodigo(r.codigo, excepto: excepto)) duplicado('codigo', 'El código de ruta ya está registrado');
  }
}

/// HU-06: servicios del turno con su ruta y prioridad.
class ServicioProgramadoServicio extends ServicioConBitacora {
  ServicioProgramadoServicio({
    required super.bd,
    required super.bitacora,
    required super.reloj,
    required this.servicios,
    required this.rutas,
  });

  final RepositorioServicios servicios;
  final RepositorioRutas rutas;

  Future<Pagina<ServicioProgramado>> listar(ParametrosPagina pagina, {DateTime? fecha, EstadoServicio? estado}) =>
      servicios.listar(pagina, fecha: fecha, estado: estado);

  Future<ServicioProgramado> obtener(int id) async =>
      await servicios.buscar(id) ?? noEncontrado('Servicio no encontrado');

  Future<ServicioProgramado> crear(ServicioProgramado servicio, UsuarioAutenticado autor) async {
    await _validar(servicio);
    final id = await servicios.crear(servicio, autor.id);
    await registrar(autor, 'crear_servicio', 'servicio', id, servicio.toJsonSolicitud());
    return obtener(id);
  }

  Future<ServicioProgramado> actualizar(int id, ServicioProgramado servicio, UsuarioAutenticado autor) async {
    final anterior = await obtener(id);
    if (anterior.estado != EstadoServicio.pendiente) {
      reglaIncumplida('estado', 'Solo se editan servicios pendientes');
    }
    final nuevo = ServicioProgramado(
      id: id,
      codigo: servicio.codigo,
      fecha: servicio.fecha,
      rutaId: servicio.rutaId,
      horaSolicitada: servicio.horaSolicitada,
      prioridad: servicio.prioridad,
      capacidadRequerida: servicio.capacidadRequerida,
    );
    await _validar(nuevo, excepto: id);
    await servicios.actualizar(nuevo);
    await registrar(autor, 'actualizar_servicio', 'servicio', id, {'antes': anterior.toJsonSolicitud(), 'despues': nuevo.toJsonSolicitud()});
    return obtener(id);
  }

  Future<ServicioProgramado> cancelar(int id, UsuarioAutenticado autor) async {
    await obtener(id);
    await servicios.cambiarEstado(bd, [id], EstadoServicio.cancelado);
    await registrar(autor, 'cancelar_servicio', 'servicio', id);
    return obtener(id);
  }

  Future<void> _validar(ServicioProgramado s, {int? excepto}) async {
    final ruta = await rutas.buscar(s.rutaId);
    if (ruta == null || !ruta.activa) reglaIncumplida('rutaId', 'Seleccione una ruta activa');
    if (!await rutas.existeSalida(s.rutaId, s.horaSolicitada)) {
      reglaIncumplida('horaSolicitada', 'La hora no es una salida autorizada de la ruta ${ruta.codigo}');
    }
    if (s.prioridad < 1 || s.prioridad > 3) reglaIncumplida('prioridad', 'La prioridad debe ser 1, 2 o 3');
    if (s.capacidadRequerida < 1) reglaIncumplida('capacidadRequerida', 'La capacidad requerida debe ser al menos 1');
    if (await servicios.existeCodigo(s.codigo, excepto: excepto)) duplicado('codigo', 'El código de servicio ya está registrado');
  }
}

/// Lectura de los parámetros vigentes (administrador).
class ParametrosServicio {
  const ParametrosServicio(this.parametros);

  final ParametrosSistema parametros;

  Map<String, Object?> vigentes() => parametros.toJson();
}
