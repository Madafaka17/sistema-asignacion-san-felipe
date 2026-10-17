import 'package:dominio/dominio.dart';

import '../configuracion/parametros_sistema.dart';
import '../infraestructura/base_datos.dart';
import '../infraestructura/reloj.dart';
import '../repositorios/repositorio_bitacora.dart';
import '../repositorios/repositorio_cola.dart';
import '../repositorios/repositorio_conductores.dart';
import '../repositorios/repositorio_pares.dart';
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

/// HU-02: registro de vehículos y de sus conductores autorizados.
class VehiculoServicio extends ServicioConBitacora {
  VehiculoServicio({
    required this.baseDatos,
    required super.bitacora,
    required super.reloj,
    required this.vehiculos,
    required this.conductores,
    required this.pares,
  }) : super(bd: baseDatos);

  final BaseDatos baseDatos;
  final RepositorioVehiculos vehiculos;
  final RepositorioConductores conductores;
  final RepositorioPares pares;

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

  /// `chab(v)` y `C_v^R` de todas las unidades.
  Future<List<ParAutorizado>> paresAutorizados() => pares.todos();

  Future<ConductoresAutorizados> conductoresDe(int id) async {
    await obtener(id);
    return pares.deVehiculo(id);
  }

  /// Reemplaza el conductor habitual y los reemplazos autorizados de la
  /// unidad (sección 3.1.2). Cada unidad tiene a lo sumo un habitual y cada
  /// conductor es habitual de una sola unidad; el cambio queda en la
  /// bitácora con el conjunto anterior y el nuevo.
  Future<ConductoresAutorizados> asignarConductores(
    int id,
    ConductoresAutorizados solicitud,
    UsuarioAutenticado autor,
  ) async {
    final vehiculo = await obtener(id);
    final habitual = solicitud.conductorHabitualId;
    final reemplazos = solicitud.reemplazos.toSet();
    if (habitual != null && reemplazos.contains(habitual)) {
      reglaIncumplida('reemplazos', 'El conductor habitual no puede figurar también como reemplazo');
    }
    final plantilla = {for (final c in await conductores.todos()) c.id: c};
    if (habitual != null && !plantilla.containsKey(habitual)) {
      reglaIncumplida('conductorHabitualId', 'El conductor habitual no existe');
    }
    if (!plantilla.keys.toSet().containsAll(reemplazos)) reglaIncumplida('reemplazos', 'Algún reemplazo no existe');
    if (habitual != null) {
      final otra = await pares.unidadHabitual(habitual);
      if (otra != null && otra != id) {
        final unidad = await vehiculos.buscar(otra);
        duplicado(
          'conductorHabitualId',
          '${plantilla[habitual]!.codigo} ya es conductor habitual de ${unidad?.codigo ?? 'otra unidad'}',
        );
      }
    }
    final nuevo = ConductoresAutorizados(
      vehiculoId: id,
      conductorHabitualId: habitual,
      reemplazos: reemplazos.toList()..sort(),
    );
    final anterior = await pares.deVehiculo(id);
    await baseDatos.transaccion((tx) async {
      await pares.reemplazar(tx, nuevo);
      await bitacora.registrar(
        tx,
        usuarioId: autor.id,
        accion: 'asignar_conductores',
        entidad: 'vehiculo',
        entidadId: id,
        detalle: {'vehiculo': vehiculo.codigo, 'antes': anterior.toJson(), 'despues': nuevo.toJson()},
        fechaHora: reloj.ahora(),
      );
    });
    return pares.deVehiculo(id);
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
      idaMin: ruta.idaMin,
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
    if (r.idaMin case final ida? when ida <= 0 || 2 * ida > r.duracionMin) {
      reglaIncumplida('idaMin', 'La duración del viaje redondo debe cubrir la ida y el retorno (al menos ${2 * ida} min)');
    }
    final existentes = {for (final v in await vehiculos.todos()) v.id};
    if (!existentes.containsAll(r.vehiculosCompatibles)) {
      reglaIncumplida('vehiculosCompatibles', 'Algún vehículo compatible no existe');
    }
    if (await rutas.existeCodigo(r.codigo, excepto: excepto)) duplicado('codigo', 'El código de ruta ya está registrado');
  }
}

/// HU-06: servicios del turno con su ruta, prioridad y turno en la cola.
class ServicioProgramadoServicio extends ServicioConBitacora {
  ServicioProgramadoServicio({
    required super.bd,
    required super.bitacora,
    required super.reloj,
    required this.servicios,
    required this.rutas,
    required this.cola,
  });

  final RepositorioServicios servicios;
  final RepositorioRutas rutas;
  final RepositorioCola cola;

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
      entradaColaId: servicio.entradaColaId,
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
    if (s.entradaColaId case final entradaId?) {
      // v0(s): el turno debe ser de la misma cola, seguir activo, no estar
      // tomado por otro servicio y la unidad debe llegar antes de la salida.
      final entrada = await cola.buscar(entradaId) ?? reglaIncumplida('entradaColaId', 'El turno de cola no existe');
      final unidad = entrada.codigoVehiculo ?? '${entrada.vehiculoId}';
      if (entrada.rutaId != s.rutaId || entrada.fecha != soloFecha(s.fecha)) {
        reglaIncumplida('entradaColaId', 'El turno elegido es de la cola de otra ruta o de otra fecha');
      }
      if (!entrada.activa) reglaIncumplida('entradaColaId', 'La unidad $unidad dejó la cola');
      if (s.horaSolicitada < entrada.llegada) {
        reglaIncumplida(
          'entradaColaId',
          'La unidad $unidad llega a la cola a las ${minutosAHora(entrada.llegada)}, después de la salida solicitada',
        );
      }
      final otro = await servicios.conEntrada(entradaId, excepto: excepto);
      if (otro != null) {
        duplicado('entradaColaId', 'El turno de $unidad (posición ${entrada.posicion}) ya corresponde al servicio ${otro.codigo}');
      }
    }
  }
}

/// Cola de despacho (sección 3.1.2): llegada de las unidades al terminal y
/// su retiro. Las unidades salen por orden de llegada.
class ColaServicio extends ServicioConBitacora {
  ColaServicio({
    required this.baseDatos,
    required super.bitacora,
    required super.reloj,
    required this.cola,
    required this.rutas,
    required this.vehiculos,
  }) : super(bd: baseDatos);

  final BaseDatos baseDatos;
  final RepositorioCola cola;
  final RepositorioRutas rutas;
  final RepositorioVehiculos vehiculos;

  Future<List<EntradaCola>> listar(DateTime fecha, {int? rutaId}) => cola.entradas(fecha, rutaId: rutaId);

  /// Registra la llegada de una unidad: recibe la posición siguiente a la
  /// última de la cola, bajo bloqueo de la cola.
  Future<EntradaCola> registrarLlegada(SolicitudEntradaCola s, UsuarioAutenticado autor) async {
    final ruta = await rutas.buscar(s.rutaId);
    if (ruta == null || !ruta.activa) reglaIncumplida('rutaId', 'Seleccione una ruta activa');
    final vehiculo = await vehiculos.buscar(s.vehiculoId) ?? reglaIncumplida('vehiculoId', 'El vehículo no existe');
    if (!vehiculo.disponible) reglaIncumplida('vehiculoId', 'La unidad ${vehiculo.codigo} no está operativa');
    if (!ruta.vehiculosCompatibles.contains(vehiculo.id)) {
      reglaIncumplida('vehiculoId', 'La unidad ${vehiculo.codigo} no es compatible con la ruta ${ruta.codigo}');
    }
    if (!esMinutoDelDia(s.llegada)) reglaIncumplida('llegada', 'La hora debe estar entre 00:00 y 23:59');
    final id = await baseDatos.transaccion((tx) async {
      final colaId = await cola.bloquearCola(tx, ruta.id, s.fecha);
      final ultima = await cola.ultima(tx, colaId);
      if (ultima != null && s.llegada < ultima.llegada) {
        reglaIncumplida(
          'llegada',
          'La cola es por orden de llegada: la última unidad llegó a las ${minutosAHora(ultima.llegada)}',
        );
      }
      final enEspera = await cola.enEspera(tx, vehiculo.id, s.fecha);
      if (enEspera != null) {
        final otra = enEspera.rutaId == ruta.id ? ruta : await rutas.buscar(enEspera.rutaId);
        duplicado(
          'vehiculoId',
          'La unidad ${vehiculo.codigo} ya espera turno en la posición ${enEspera.posicion} de la cola de '
              '${otra?.codigo ?? 'otra ruta'}',
        );
      }
      final posicion = (ultima?.posicion ?? 0) + 1;
      final id = await cola.insertar(
        tx,
        colaId: colaId,
        vehiculoId: vehiculo.id,
        posicion: posicion,
        llegada: s.llegada,
        usuarioId: autor.id,
      );
      await bitacora.registrar(
        tx,
        usuarioId: autor.id,
        accion: 'registrar_llegada',
        entidad: 'entrada_cola',
        entidadId: id,
        detalle: {
          'ruta': ruta.codigo,
          'fecha': fechaATexto(s.fecha),
          'vehiculo': vehiculo.codigo,
          'posicion': posicion,
          'llegada': minutosAHora(s.llegada),
        },
        fechaHora: reloj.ahora(),
      );
      return id;
    });
    return (await cola.buscar(id))!;
  }

  /// La unidad deja la cola: la entrada queda inactiva y conserva su
  /// posición; si correspondía a un servicio, la generación usará la
  /// siguiente unidad elegible (salto de cola).
  Future<EntradaCola> retirar(int id, UsuarioAutenticado autor) async {
    final entrada = await cola.buscar(id) ?? noEncontrado('Turno de cola no encontrado');
    if (!entrada.activa) reglaIncumplida('activa', 'La unidad ${entrada.codigoVehiculo} ya dejó la cola');
    await cola.retirar(id, reloj.ahora());
    await registrar(autor, 'retirar_de_cola', 'entrada_cola', id, {
      'vehiculo': entrada.codigoVehiculo,
      'posicion': entrada.posicion,
      'servicio': entrada.codigoServicio,
    });
    return (await cola.buscar(id))!;
  }
}

/// Lectura de los parámetros vigentes (administrador).
class ParametrosServicio {
  const ParametrosServicio(this.parametros);

  final ParametrosSistema parametros;

  Map<String, Object?> vigentes() => parametros.toJson();
}
