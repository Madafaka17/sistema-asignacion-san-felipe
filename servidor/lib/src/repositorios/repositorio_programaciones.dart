import 'package:dominio/dominio.dart';

import '../infraestructura/base_datos.dart';

/// Datos de una asignación por guardar (`x_{s,a} = 1` o `u_s = 1`).
class NuevaAsignacion {
  const NuevaAsignacion({
    required this.servicioId,
    this.vehiculoId,
    this.conductorId,
    this.salida,
    this.fin,
    required this.estado,
    this.motivo,
  });

  final int servicioId;
  final int? vehiculoId;
  final int? conductorId;
  final int? salida;
  final int? fin;
  final EstadoAsignacion estado;
  final String? motivo;
}

/// Programación propuesta por el módulo de optimización, lista para guardar.
class NuevaProgramacion {
  const NuevaProgramacion({
    required this.fecha,
    required this.metodo,
    required this.aptitud,
    required this.phi,
    required this.phiValidador,
    required this.componentes,
    required this.generaciones,
    required this.tiempoMs,
    this.semilla,
    required this.vehiculosDisponibles,
    required this.parametrosJson,
    required this.creadoPor,
    required this.creadoEn,
    required this.asignaciones,
    required this.historial,
  });

  final DateTime fecha;
  final String metodo;
  final double aptitud;
  final int phi;
  final int phiValidador;
  final ComponentesAptitud componentes;
  final int generaciones;
  final int tiempoMs;
  final int? semilla;
  final int vehiculosDisponibles;
  final String parametrosJson;
  final int creadoPor;
  final DateTime creadoEn;
  final List<NuevaAsignacion> asignaciones;
  final List<PuntoConvergencia> historial;
}

abstract interface class RepositorioProgramaciones {
  Future<int> guardar(Ejecutor ejecutor, NuevaProgramacion programacion);

  Future<Programacion?> buscar(int id);

  Future<List<Programacion>> listar({DateTime? fecha});

  Future<Programacion?> aprobadaDe(DateTime fecha);

  /// `b(s)` de la ecuación (8): asignaciones de la programación aprobada.
  Future<Map<int, Alternativa>> comprometidas(DateTime fecha);

  Future<void> actualizarAsignacion(Ejecutor ejecutor, int programacionId, NuevaAsignacion asignacion, {bool ajustada});

  Future<void> actualizarMetricas(Ejecutor ejecutor, int id, {required int phiValidador, required ComponentesAptitud componentes});

  Future<void> reemplazarAprobada(Ejecutor ejecutor, DateTime fecha);

  Future<void> aprobar(Ejecutor ejecutor, int id, int usuarioId, DateTime momento);
}

class RepositorioProgramacionesMysql implements RepositorioProgramaciones {
  const RepositorioProgramacionesMysql(this._bd);

  final BaseDatos _bd;

  @override
  Future<int> guardar(Ejecutor tx, NuevaProgramacion p) async {
    final c = p.componentes;
    final id = (await tx.ejecutar(
      'INSERT INTO programacion (fecha, metodo, aptitud, phi, phi_validador, conflictos_vehiculo, '
      'conflictos_conductor, conductores_excedidos, exceso_min, retraso_min, reprogramados, tiempo_muerto_min, '
      'desviacion_carga, perdida, generaciones, tiempo_ms, semilla, vehiculos_disponibles, parametros, '
      'creado_por, creado_en) VALUES (:fecha, :metodo, :aptitud, :phi, :phiV, :cv, :cc, :nexc, :exceso, '
      ':retraso, :reprog, :tm, :d, :j, :gen, :ms, :semilla, :vehiculos, :parametros, :usuario, :creado)',
      {
        'fecha': formatoFecha(p.fecha),
        'metodo': p.metodo,
        'aptitud': p.aptitud,
        'phi': p.phi,
        'phiV': p.phiValidador,
        'cv': c.conflictosVehiculo,
        'cc': c.conflictosConductor,
        'nexc': c.conductoresExcedidos,
        'exceso': c.excesoMin,
        'retraso': c.retrasoMin,
        'reprog': c.reprogramados,
        'tm': c.tiempoMuertoMin,
        'd': c.desviacionCarga,
        'j': c.perdida,
        'gen': p.generaciones,
        'ms': p.tiempoMs,
        'semilla': p.semilla,
        'vehiculos': p.vehiculosDisponibles,
        'parametros': p.parametrosJson,
        'usuario': p.creadoPor,
        'creado': p.creadoEn,
      },
    ))
        .idInsertado;

    for (final lote in _lotes(p.asignaciones, 100)) {
      final valores = <String>[];
      final parametros = <String, Object?>{'programacion': id};
      for (final (i, a) in lote.indexed) {
        valores.add('(:programacion, :s$i, :v$i, :c$i, :h$i, :f$i, :e$i, :m$i)');
        parametros.addAll({
          's$i': a.servicioId,
          'v$i': a.vehiculoId,
          'c$i': a.conductorId,
          'h$i': a.salida,
          'f$i': a.fin,
          'e$i': a.estado.valor,
          'm$i': a.motivo,
        });
      }
      await tx.ejecutar(
        'INSERT INTO asignacion (programacion_id, servicio_id, vehiculo_id, conductor_id, salida, fin, estado, motivo) '
        'VALUES ${valores.join(', ')}',
        parametros,
      );
    }

    for (final lote in _lotes(p.historial, 200)) {
      final valores = <String>[];
      final parametros = <String, Object?>{'programacion': id};
      for (final (i, punto) in lote.indexed) {
        valores.add('(:programacion, :g$i, :b$i, :p$i)');
        parametros.addAll({'g$i': punto.generacion, 'b$i': punto.mejor, 'p$i': punto.promedio});
      }
      await tx.ejecutar(
        'INSERT INTO historial_aptitud (programacion_id, generacion, mejor, promedio) VALUES ${valores.join(', ')}',
        parametros,
      );
    }
    return id;
  }

  static const _columnasProgramacion =
      'p.id, p.fecha, p.estado, p.metodo, p.aptitud, p.phi, p.phi_validador, p.conflictos_vehiculo, '
      'p.conflictos_conductor, p.conductores_excedidos, p.exceso_min, p.retraso_min, p.reprogramados, '
      'p.tiempo_muerto_min, p.desviacion_carga, p.perdida, p.generaciones, p.tiempo_ms, p.semilla, '
      'p.creado_en, p.aprobado_en, uc.nombre_usuario AS creador, ua.nombre_usuario AS aprobador';
  static const _desdeProgramacion = 'FROM programacion p LEFT JOIN usuario uc ON uc.id = p.creado_por '
      'LEFT JOIN usuario ua ON ua.id = p.aprobado_por';

  static Programacion _programacion(Fila f, {List<Asignacion> asignaciones = const [], List<PuntoConvergencia> historial = const []}) =>
      Programacion(
        id: f.entero('id'),
        fecha: f.fecha('fecha'),
        estado: EstadoProgramacion.desdeValor(f.texto('estado')),
        metodo: f.texto('metodo'),
        aptitud: f.decimal('aptitud'),
        phi: f.entero('phi'),
        phiValidador: f.entero('phi_validador'),
        componentes: ComponentesAptitud(
          conflictosVehiculo: f.entero('conflictos_vehiculo'),
          conflictosConductor: f.entero('conflictos_conductor'),
          conductoresExcedidos: f.entero('conductores_excedidos'),
          excesoMin: f.entero('exceso_min'),
          retrasoMin: f.entero('retraso_min'),
          reprogramados: f.entero('reprogramados'),
          tiempoMuertoMin: f.entero('tiempo_muerto_min'),
          desviacionCarga: f.decimal('desviacion_carga'),
          perdida: f.decimal('perdida'),
        ),
        generaciones: f.entero('generaciones'),
        tiempoMs: f.entero('tiempo_ms'),
        semilla: f.enteroNulo('semilla'),
        creadoPor: f.textoNulo('creador') ?? '—',
        creadoEn: f.fechaHora('creado_en'),
        aprobadoPor: f.textoNulo('aprobador'),
        aprobadoEn: f.fechaHoraNula('aprobado_en'),
        asignaciones: asignaciones,
        historial: historial,
      );

  @override
  Future<Programacion?> buscar(int id) async {
    final filas = await _bd.consultar('SELECT $_columnasProgramacion $_desdeProgramacion WHERE p.id = :id', {'id': id});
    if (filas.isEmpty) return null;
    final asignaciones = await _bd.consultar(
      'SELECT a.servicio_id, s.codigo AS servicio, r.codigo AS ruta, s.prioridad, a.vehiculo_id, '
      'v.codigo AS vehiculo, a.conductor_id, c.codigo AS conductor, a.salida, a.fin, a.estado, a.motivo, a.ajustada '
      'FROM asignacion a JOIN servicio s ON s.id = a.servicio_id JOIN ruta r ON r.id = s.ruta_id '
      'LEFT JOIN vehiculo v ON v.id = a.vehiculo_id LEFT JOIN conductor c ON c.id = a.conductor_id '
      'WHERE a.programacion_id = :id',
      {'id': id},
    );
    final historial = await _bd.consultar(
      'SELECT generacion, mejor, promedio FROM historial_aptitud WHERE programacion_id = :id ORDER BY generacion',
      {'id': id},
    );
    return _programacion(
      filas.single,
      asignaciones: [
        for (final a in asignaciones)
          Asignacion(
            servicioId: a.entero('servicio_id'),
            codigoServicio: a.texto('servicio'),
            codigoRuta: a.texto('ruta'),
            prioridad: a.entero('prioridad'),
            vehiculoId: a.enteroNulo('vehiculo_id'),
            codigoVehiculo: a.textoNulo('vehiculo'),
            conductorId: a.enteroNulo('conductor_id'),
            codigoConductor: a.textoNulo('conductor'),
            salida: a.enteroNulo('salida'),
            fin: a.enteroNulo('fin'),
            estado: EstadoAsignacion.desdeValor(a.texto('estado')),
            motivo: a.textoNulo('motivo'),
            ajustada: a.booleano('ajustada'),
          ),
      ]..sort(Asignacion.compararParaVista),
      historial: [
        for (final h in historial) PuntoConvergencia(h.entero('generacion'), h.decimal('mejor'), h.decimal('promedio')),
      ],
    );
  }

  @override
  Future<List<Programacion>> listar({DateTime? fecha}) async => (await _bd.consultar(
        'SELECT $_columnasProgramacion $_desdeProgramacion '
        '${fecha == null ? '' : 'WHERE p.fecha = :fecha'} ORDER BY p.id DESC LIMIT 100',
        {'fecha': fecha == null ? null : formatoFecha(fecha)},
      ))
          .map(_programacion)
          .toList();

  @override
  Future<Programacion?> aprobadaDe(DateTime fecha) async {
    final filas = await _bd.consultar(
      "SELECT p.id FROM programacion p WHERE p.fecha = :fecha AND p.estado = 'aprobada'",
      {'fecha': formatoFecha(fecha)},
    );
    return filas.isEmpty ? null : buscar(filas.single.entero('id'));
  }

  @override
  Future<Map<int, Alternativa>> comprometidas(DateTime fecha) async {
    final filas = await _bd.consultar(
      'SELECT a.servicio_id, a.vehiculo_id, a.conductor_id, a.salida, a.fin FROM asignacion a '
      "JOIN programacion p ON p.id = a.programacion_id WHERE p.fecha = :fecha AND p.estado = 'aprobada' "
      "AND a.estado = 'asignado'",
      {'fecha': formatoFecha(fecha)},
    );
    return {
      for (final f in filas)
        f.entero('servicio_id'): Alternativa(
          vehiculoId: f.entero('vehiculo_id'),
          conductorId: f.entero('conductor_id'),
          salida: f.entero('salida'),
          duracion: f.entero('fin') - f.entero('salida'),
        ),
    };
  }

  @override
  Future<void> actualizarAsignacion(
    Ejecutor tx,
    int programacionId,
    NuevaAsignacion a, {
    bool ajustada = false,
  }) =>
      tx.ejecutar(
        'UPDATE asignacion SET vehiculo_id = :v, conductor_id = :c, salida = :h, fin = :f, estado = :e, '
        'motivo = :m, ajustada = ajustada OR :ajustada WHERE programacion_id = :p AND servicio_id = :s',
        {
          'p': programacionId,
          's': a.servicioId,
          'v': a.vehiculoId,
          'c': a.conductorId,
          'h': a.salida,
          'f': a.fin,
          'e': a.estado.valor,
          'm': a.motivo,
          'ajustada': ajustada,
        },
      );

  @override
  Future<void> actualizarMetricas(
    Ejecutor tx,
    int id, {
    required int phiValidador,
    required ComponentesAptitud componentes,
  }) =>
      tx.ejecutar(
        'UPDATE programacion SET phi_validador = :phiV, retraso_min = :ret, reprogramados = :r, '
        'tiempo_muerto_min = :tm, desviacion_carga = :d WHERE id = :id',
        {
          'id': id,
          'phiV': phiValidador,
          'ret': componentes.retrasoMin,
          'r': componentes.reprogramados,
          'tm': componentes.tiempoMuertoMin,
          'd': componentes.desviacionCarga,
        },
      );

  @override
  Future<void> reemplazarAprobada(Ejecutor tx, DateTime fecha) => tx.ejecutar(
        "UPDATE programacion SET estado = 'reemplazada' WHERE fecha = :fecha AND estado = 'aprobada'",
        {'fecha': formatoFecha(fecha)},
      );

  @override
  Future<void> aprobar(Ejecutor tx, int id, int usuarioId, DateTime momento) => tx.ejecutar(
        "UPDATE programacion SET estado = 'aprobada', aprobado_por = :usuario, aprobado_en = :momento WHERE id = :id",
        {'id': id, 'usuario': usuarioId, 'momento': momento},
      );

  static Iterable<List<T>> _lotes<T>(List<T> lista, int tamano) sync* {
    for (var i = 0; i < lista.length; i += tamano) {
      yield lista.sublist(i, i + tamano > lista.length ? lista.length : i + tamano);
    }
  }
}
