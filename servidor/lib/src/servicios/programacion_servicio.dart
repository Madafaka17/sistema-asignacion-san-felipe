import 'dart:isolate';

import 'package:dominio/dominio.dart';

import '../configuracion/parametros_sistema.dart';
import '../infraestructura/base_datos.dart';
import '../infraestructura/reloj.dart';
import '../repositorios/repositorio_bitacora.dart';
import '../repositorios/repositorio_conductores.dart';
import '../repositorios/repositorio_programaciones.dart';
import '../repositorios/repositorio_rutas.dart';
import '../repositorios/repositorio_servicios.dart';
import '../repositorios/repositorio_vehiculos.dart';
import '../seguridad/tokens.dart';
import 'registros_servicio.dart';

/// Caso de uso principal (HU-07, HU-08 y HU-09; Figura 5 de la tesis):
/// genera la propuesta de programación, permite ajustarla y aprobarla.
class ProgramacionServicio {
  ProgramacionServicio({
    required this.bd,
    required this.servicios,
    required this.vehiculos,
    required this.conductores,
    required this.rutas,
    required this.programaciones,
    required this.bitacora,
    required this.parametros,
    required this.reloj,
  });

  final BaseDatos bd;
  final RepositorioServicios servicios;
  final RepositorioVehiculos vehiculos;
  final RepositorioConductores conductores;
  final RepositorioRutas rutas;
  final RepositorioProgramaciones programaciones;
  final RepositorioBitacora bitacora;
  final ParametrosSistema parametros;
  final Reloj reloj;

  static const sinPendientes = 'No hay servicios pendientes para el turno seleccionado';

  Future<List<Programacion>> listar({DateTime? fecha}) => programaciones.listar(fecha: fecha);

  Future<Programacion> obtener(int id) async =>
      await programaciones.buscar(id) ?? noEncontrado('Programación no encontrada');

  /// HU-07: genera una propuesta para la fecha. Cada ejecución crea un
  /// registro nuevo; la programación aprobada no se modifica.
  Future<Programacion> generar(DateTime fecha, UsuarioAutenticado usuario) async {
    final cronometro = Stopwatch()..start();
    final pendientes = await servicios.deFecha(fecha, {EstadoServicio.pendiente});
    if (pendientes.isEmpty) throw ExcepcionApi(CodigoError.reglaNegocio, sinPendientes);

    // La lógica de negocio construye la instancia del turno: A_s (ec. 1) y
    // los datos de Γ, de los límites y de la programación comprometida b(s).
    final (instancia, vehiculosDisponibles) = await _instancia(fecha);

    // El núcleo de optimización se ejecuta en un isolate aparte para no
    // bloquear el bucle de eventos del servidor durante el cálculo.
    final estrategia = FabricaEstrategias.crear(
      parametros.metodo,
      parametrosAG: parametros.algoritmoGenetico,
    );
    final resultado = await _optimizarEnIsolate(estrategia, instancia);

    final decodificado = Decodificador(instancia).decodificar(resultado.cromosoma);
    final asignadas = [for (final r in decodificado) if (r.asignado) r];
    final validacion = Validador(holguraMinima: instancia.holguraMinima).validar(
      [for (final r in asignadas) _validable(r.servicio.servicioId, r.alternativa!)],
      _limites(instancia),
    );
    final tiempoMs = cronometro.elapsedMilliseconds;

    final id = await bd.transaccion((tx) async {
      final id = await programaciones.guardar(
        tx,
        NuevaProgramacion(
          fecha: fecha,
          metodo: resultado.metodo,
          aptitud: resultado.evaluacion.aptitud,
          phi: resultado.evaluacion.phi,
          phiValidador: validacion.phi,
          componentes: resultado.evaluacion.componentes,
          generaciones: resultado.generaciones,
          tiempoMs: tiempoMs,
          semilla: resultado.semilla,
          vehiculosDisponibles: vehiculosDisponibles,
          parametrosJson: parametros.aJson(),
          creadoPor: usuario.id,
          creadoEn: reloj.ahora(),
          asignaciones: [
            for (final r in decodificado)
              r.asignado
                  ? NuevaAsignacion(
                      servicioId: r.servicio.servicioId,
                      vehiculoId: r.alternativa!.vehiculoId,
                      conductorId: r.alternativa!.conductorId,
                      salida: r.alternativa!.salida,
                      fin: r.alternativa!.fin,
                      estado: EstadoAsignacion.asignado,
                    )
                  : NuevaAsignacion(
                      servicioId: r.servicio.servicioId,
                      estado: EstadoAsignacion.incidencia,
                      motivo: r.motivo,
                    ),
          ],
          historial: resultado.historial,
        ),
      );
      await bitacora.registrar(
        tx,
        usuarioId: usuario.id,
        accion: 'generar_programacion',
        entidad: 'programacion',
        entidadId: id,
        detalle: {
          'fecha': fechaATexto(fecha),
          'metodo': resultado.metodo,
          'aptitud': resultado.evaluacion.aptitud,
          'phi': resultado.evaluacion.phi,
          'phiValidador': validacion.phi,
          'asignados': asignadas.length,
          'incidencias': decodificado.length - asignadas.length,
          'tiempoMs': tiempoMs,
        },
        fechaHora: reloj.ahora(),
      );
      return id;
    });
    return obtener(id);
  }

  /// HU-09: ajuste manual de una asignación. La alternativa debe ser
  /// admisible (ecuación 1); si deja un cruce, se guarda marcada como
  /// conflicto y la programación no puede aprobarse hasta resolverlo.
  Future<Programacion> ajustar(
    int programacionId,
    int servicioId,
    AjusteAsignacion ajuste,
    UsuarioAutenticado usuario,
  ) async {
    final programacion = await obtener(programacionId);
    if (programacion.estado != EstadoProgramacion.propuesta) {
      throw ExcepcionApi(CodigoError.reglaNegocio, 'Solo se ajusta una programación propuesta');
    }
    final anterior = programacion.asignaciones.where((a) => a.servicioId == servicioId).firstOrNull ??
        noEncontrado('El servicio no pertenece a la programación');

    final (instancia, _) = await _instancia(programacion.fecha, incluir: {for (final a in programacion.asignaciones) a.servicioId});
    final servicio = instancia.servicios.where((s) => s.servicioId == servicioId).firstOrNull ??
        noEncontrado('Servicio no encontrado');
    final alternativa = servicio.alternativas
        .where((a) => a.vehiculoId == ajuste.vehiculoId && a.conductorId == ajuste.conductorId && a.salida == ajuste.salida)
        .firstOrNull;
    if (alternativa == null) {
      throw ExcepcionApi(
        CodigoError.reglaNegocio,
        await _motivoInadmisible(servicio, ajuste, programacion.fecha),
      );
    }

    // Programación resultante: la vigente con la alternativa ajustada.
    final elegidas = <int, Alternativa>{
      for (final a in programacion.asignaciones)
        if (a.tieneRecursos && a.servicioId != servicioId)
          a.servicioId: Alternativa(
            vehiculoId: a.vehiculoId!,
            conductorId: a.conductorId!,
            salida: a.salida!,
            duracion: a.fin! - a.salida!,
          ),
      servicioId: alternativa,
    };
    final (estados, phiValidador) = _estadosTrasValidar(instancia, elegidas, programacion);
    final evaluacion = Evaluador(instancia).evaluarProgramacion(elegidas);

    await bd.transaccion((tx) async {
      for (final entrada in elegidas.entries) {
        final (estado, motivo) = estados[entrada.key]!;
        await programaciones.actualizarAsignacion(
          tx,
          programacionId,
          NuevaAsignacion(
            servicioId: entrada.key,
            vehiculoId: entrada.value.vehiculoId,
            conductorId: entrada.value.conductorId,
            salida: entrada.value.salida,
            fin: entrada.value.fin,
            estado: estado,
            motivo: motivo,
          ),
          ajustada: entrada.key == servicioId,
        );
      }
      await programaciones.actualizarMetricas(
        tx,
        programacionId,
        phiValidador: phiValidador,
        componentes: evaluacion.componentes,
      );
      await bitacora.registrar(
        tx,
        usuarioId: usuario.id,
        accion: 'ajustar_asignacion',
        entidad: 'programacion',
        entidadId: programacionId,
        detalle: {
          'servicio': anterior.codigoServicio,
          'antes': {'vehiculoId': anterior.vehiculoId, 'conductorId': anterior.conductorId, 'salida': anterior.salida},
          'despues': ajuste.toJson(),
          'conflictos': [for (final e in estados.entries) if (e.value.$1 == EstadoAsignacion.conflicto) e.key],
        },
        fechaHora: reloj.ahora(),
      );
    });
    return obtener(programacionId);
  }

  /// HU-09: aprobación. Requiere que el validador independiente confirme
  /// Φ = 0 en las asignaciones; los servicios sin cobertura quedan como
  /// incidencias pendientes.
  Future<Programacion> aprobar(int id, UsuarioAutenticado usuario) async {
    final programacion = await obtener(id);
    if (programacion.estado != EstadoProgramacion.propuesta) {
      throw ExcepcionApi(CodigoError.reglaNegocio, 'Solo se aprueba una programación propuesta');
    }
    final conRecursos = [for (final a in programacion.asignaciones) if (a.tieneRecursos) a];
    final todosConductores = await conductores.todos();
    final validacion = Validador(holguraMinima: parametros.modelo.holguraMinima).validar(
      [
        for (final a in conRecursos)
          AsignacionValidable(
            servicioId: a.servicioId,
            vehiculoId: a.vehiculoId!,
            conductorId: a.conductorId!,
            inicio: a.salida!,
            fin: a.fin!,
          ),
      ],
      {for (final c in todosConductores) c.id: LimiteConduccion(c.minutosAcumulados, c.limiteMinutos)},
    );
    if (!validacion.esFactible) {
      final codigos = {for (final a in programacion.asignaciones) a.servicioId: a.codigoServicio};
      final codigosConductor = {for (final c in todosConductores) c.id: c.codigo};
      final detalle = [
        for (final c in validacion.cruces) '${codigos[c.servicioA]} y ${codigos[c.servicioB]}',
        for (final c in validacion.conductoresExcedidos.keys) 'límite de conducción de ${codigosConductor[c]}',
      ];
      throw ExcepcionApi(
        CodigoError.conflicto,
        'La programación tiene cruces sin resolver: ${detalle.join('; ')}',
      );
    }

    await bd.transaccion((tx) async {
      final ahora = reloj.ahora();
      await programaciones.reemplazarAprobada(tx, programacion.fecha);
      await programaciones.aprobar(tx, id, usuario.id, ahora);
      await servicios.cambiarEstado(
        tx,
        [for (final a in programacion.asignaciones) if (a.estado == EstadoAsignacion.asignado) a.servicioId],
        EstadoServicio.programado,
      );
      await servicios.cambiarEstado(
        tx,
        [for (final a in programacion.asignaciones) if (a.estado == EstadoAsignacion.incidencia) a.servicioId],
        EstadoServicio.pendiente,
      );
      await bitacora.registrar(
        tx,
        usuarioId: usuario.id,
        accion: 'aprobar_programacion',
        entidad: 'programacion',
        entidadId: id,
        detalle: {
          'fecha': fechaATexto(programacion.fecha),
          'asignados': programacion.asignados,
          'incidencias': programacion.pendientes,
        },
        fechaHora: ahora,
      );
    });
    return obtener(id);
  }

  Future<(InstanciaTurno, int)> _instancia(DateTime fecha, {Set<int> incluir = const {}}) async {
    final delDia = await servicios.deFecha(fecha, {EstadoServicio.pendiente, EstadoServicio.programado});
    final todosVehiculos = await vehiculos.todos();
    final datos = DatosTurno(
      fecha: fecha,
      servicios: [
        ...delDia,
        for (final id in incluir)
          if (!delDia.any((s) => s.id == id)) ?(await servicios.buscar(id)),
      ],
      vehiculos: todosVehiculos,
      conductores: await conductores.todos(),
      rutas: await rutas.todas(),
      salidas: await rutas.salidas(),
      comprometidas: await programaciones.comprometidas(fecha),
    );
    return (
      ConstructorInstancia(parametros.modelo).construir(datos),
      todosVehiculos.where((v) => v.disponible).length,
    );
  }

  (Map<int, (EstadoAsignacion, String?)>, int) _estadosTrasValidar(
    InstanciaTurno instancia,
    Map<int, Alternativa> elegidas,
    Programacion programacion,
  ) {
    final validacion = Validador(holguraMinima: instancia.holguraMinima).validar(
      [for (final e in elegidas.entries) _validable(e.key, e.value)],
      _limites(instancia),
    );
    final codigos = {for (final a in programacion.asignaciones) a.servicioId: a.codigoServicio};
    final motivos = <int, String>{};
    for (final c in validacion.cruces) {
      final recurso = c.porVehiculo
          ? 'el vehículo ${instancia.codigosVehiculo[c.recursoId] ?? c.recursoId}'
          : 'el conductor ${instancia.conductores[c.recursoId]?.codigo ?? c.recursoId}';
      motivos[c.servicioA] = 'Cruce con ${codigos[c.servicioB]} por $recurso';
      motivos[c.servicioB] = 'Cruce con ${codigos[c.servicioA]} por $recurso';
    }
    validacion.conductoresExcedidos.forEach((conductorId, total) {
      final conductor = instancia.conductores[conductorId];
      for (final e in elegidas.entries) {
        if (e.value.conductorId == conductorId) {
          motivos[e.key] = 'Supera el límite de conducción de ${conductor?.codigo ?? conductorId} '
              '($total > ${conductor?.limite} min)';
        }
      }
    });
    return (
      {
        for (final id in elegidas.keys)
          id: motivos.containsKey(id) ? (EstadoAsignacion.conflicto, motivos[id]) : (EstadoAsignacion.asignado, null),
      },
      validacion.phi,
    );
  }

  /// Explica qué condición de la ecuación (1) incumple un ajuste.
  Future<String> _motivoInadmisible(ServicioTurno servicio, AjusteAsignacion ajuste, DateTime fecha) async {
    final vehiculo = await vehiculos.buscar(ajuste.vehiculoId);
    final conductor = await conductores.buscar(ajuste.conductorId);
    final detalle = await servicios.buscar(servicio.servicioId);
    final ruta = detalle == null ? null : await rutas.buscar(detalle.rutaId);
    if (vehiculo == null) return 'El vehículo no existe';
    if (conductor == null) return 'El conductor no existe';
    if (!vehiculo.disponible) return 'El vehículo ${vehiculo.codigo} no está operativo';
    if (ruta != null && !ruta.vehiculosCompatibles.contains(vehiculo.id)) {
      return 'El vehículo ${vehiculo.codigo} no es compatible con la ruta ${ruta.codigo}';
    }
    if (vehiculo.capacidad < servicio.capacidadRequerida) {
      return 'El vehículo ${vehiculo.codigo} no tiene ${servicio.capacidadRequerida} asientos';
    }
    if (!conductor.disponible || !conductor.licenciaVigente(fecha)) {
      return 'El conductor ${conductor.codigo} no está disponible o su licencia no está vigente';
    }
    if (!parametros.modelo.habilita(conductor.categoriaLicencia, vehiculo.categoria)) {
      return 'La licencia ${conductor.categoriaLicencia.valor} de ${conductor.codigo} no habilita '
          'la categoría ${vehiculo.categoria.valor}';
    }
    if (!servicio.alternativas.any((a) => a.salida == ajuste.salida)) {
      return 'Las ${minutosAHora(ajuste.salida)} no es una salida autorizada para el servicio';
    }
    return 'El servicio no cabe en el turno del conductor ${conductor.codigo}';
  }

  static AsignacionValidable _validable(int servicioId, Alternativa a) => AsignacionValidable(
        servicioId: servicioId,
        vehiculoId: a.vehiculoId,
        conductorId: a.conductorId,
        inicio: a.inicio,
        fin: a.fin,
      );

  static Map<int, LimiteConduccion> _limites(InstanciaTurno instancia) => {
        for (final c in instancia.conductores.values) c.id: LimiteConduccion(c.acumulado, c.limite),
      };
}

/// Función de nivel superior: el cierre que recibe `Isolate.run` solo debe
/// capturar la estrategia y la instancia. Si se creara dentro de un método,
/// capturaría también el servicio (con el pool de MySQL), que no puede
/// enviarse a otro isolate.
Future<ResultadoOptimizacion> _optimizarEnIsolate(EstrategiaOptimizacion estrategia, InstanciaTurno instancia) =>
    Isolate.run(() => estrategia.resolver(instancia));
