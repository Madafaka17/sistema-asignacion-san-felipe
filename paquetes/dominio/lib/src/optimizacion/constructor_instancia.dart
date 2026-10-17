import '../modelos/cola.dart';
import '../modelos/conductor.dart';
import '../modelos/par_autorizado.dart';
import '../modelos/ruta.dart';
import '../modelos/servicio_programado.dart';
import '../modelos/tiempo.dart';
import '../modelos/vehiculo.dart';
import 'instancia.dart';
import 'parametros.dart';

/// Datos del turno que la capa de datos entrega a la lógica de negocio.
class DatosTurno {
  const DatosTurno({
    required this.fecha,
    required this.servicios,
    required this.vehiculos,
    required this.conductores,
    required this.rutas,
    required this.salidas,
    this.entradas = const [],
    this.pares = const [],
    this.comprometidas = const {},
  });

  final DateTime fecha;

  /// Servicios a programar (pendientes y, en una reprogramación, los ya
  /// programados de la fecha).
  final List<ServicioProgramado> servicios;
  final List<Vehiculo> vehiculos;
  final List<Conductor> conductores;
  final List<Ruta> rutas;
  final List<SalidaAutorizada> salidas;

  /// Entradas de las colas de despacho de la fecha, activas e inactivas:
  /// definen `v0(s)`, `π(s)` y `v1(s)`.
  final List<EntradaCola> entradas;

  /// Pares autorizados vigentes: `chab(v)` y `C_v^R`.
  final List<ParAutorizado> pares;

  /// `b(s)`: id del servicio → alternativa de la programación aprobada.
  final Map<int, Alternativa> comprometidas;

  /// Contenido del snapshot de entrada (sección 5.5 de la tesis): cada lista
  /// en orden de id, para que la misma entrada tenga la misma huella con
  /// [jsonCanonico].
  Map<String, Object?> toJson() {
    List<Map<String, Object?>> ordenar<T>(List<T> lista, int Function(T) id, Map<String, Object?> Function(T) json) =>
        [for (final e in [...lista]..sort((a, b) => id(a).compareTo(id(b)))) json(e)];
    return {
      'fecha': fechaATexto(fecha),
      'servicios': ordenar(servicios, (s) => s.id, (s) => s.toJson()),
      'vehiculos': ordenar(vehiculos, (v) => v.id, (v) => v.toJson()),
      'conductores': ordenar(conductores, (c) => c.id, (c) => c.toJson()),
      'rutas': ordenar(rutas, (r) => r.id, (r) => r.toJson()),
      'salidas': ordenar(salidas, (s) => s.id, (s) => s.toJson()),
      'entradas': ordenar(entradas, (e) => e.id, (e) => e.toJson()),
      'pares': [
        for (final p in [...pares]
          ..sort((a, b) => a.vehiculoId != b.vehiculoId
              ? a.vehiculoId.compareTo(b.vehiculoId)
              : a.conductorId.compareTo(b.conductorId)))
          p.toJson(),
      ],
      'comprometidas': {
        for (final id in comprometidas.keys.toList()..sort()) '$id': comprometidas[id]!.toJson(),
      },
    };
  }

  factory DatosTurno.fromJson(Map<String, Object?> json) {
    List<T> lista<T>(String clave, T Function(Object?) desdeJson) =>
        [for (final e in json[clave] as List<Object?>) desdeJson(e)];
    return DatosTurno(
      fecha: textoAFecha(json['fecha'] as String),
      servicios: lista('servicios', ServicioProgramado.fromJson),
      vehiculos: lista('vehiculos', Vehiculo.fromJson),
      conductores: lista('conductores', Conductor.fromJson),
      rutas: lista('rutas', Ruta.fromJson),
      salidas: lista('salidas', SalidaAutorizada.fromJson),
      entradas: lista('entradas', EntradaCola.fromJson),
      pares: lista('pares', ParAutorizado.fromJson),
      comprometidas: {
        for (final e in (json['comprometidas'] as Map).entries)
          int.parse(e.key as String): Alternativa.fromJson((e.value as Map).cast<String, Object?>()),
      },
    );
  }
}

/// Construye la instancia del turno: aplica la ecuación (1) —con las reglas
/// de cola y de conductores de la sección 3.1.2— para obtener `A_s` y
/// prepara `H_c0`, `H_cmáx`, `w` y `b`.
class ConstructorInstancia {
  const ConstructorInstancia(this.parametros);

  final ParametrosModelo parametros;

  InstanciaTurno construir(DatosTurno datos) {
    final rutas = {for (final r in datos.rutas) r.id: r};
    final salidasPorRuta = <int, List<SalidaAutorizada>>{};
    for (final salida in datos.salidas) {
      salidasPorRuta.putIfAbsent(salida.rutaId, () => []).add(salida);
    }
    for (final lista in salidasPorRuta.values) {
      lista.sort((a, b) => a.hora.compareTo(b.hora));
    }

    // E_v(h) = 1: la unidad está operativa.
    final vehiculos = datos.vehiculos.where((v) => v.disponible).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final operativas = {for (final v in vehiculos) v.id: v};
    // E_c(h) = 1: el conductor está disponible, su licencia está vigente en la
    // fecha y aún no agotó su límite de conducción.
    final conductores = datos.conductores
        .where((c) =>
            c.disponible && c.licenciaVigente(datos.fecha) && c.minutosAcumulados < c.limiteMinutos)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    // Cola de despacho: entradas por id y, por ruta, las activas en orden de π.
    final entradas = {for (final e in datos.entradas) e.id: e};
    final activasPorRuta = <int, List<EntradaCola>>{};
    for (final e in datos.entradas) {
      if (e.activa) activasPorRuta.putIfAbsent(e.rutaId, () => []).add(e);
    }
    for (final lista in activasPorRuta.values) {
      lista.sort((a, b) => a.posicion.compareTo(b.posicion));
    }

    // Pares autorizados: chab(v) y C_v^R.
    final habituales = <int, int>{};
    final autorizados = <int, Set<int>>{};
    for (final p in datos.pares) {
      autorizados.putIfAbsent(p.vehiculoId, () => {}).add(p.conductorId);
      if (p.tipo == TipoPar.habitual) habituales[p.vehiculoId] = p.conductorId;
    }
    bool autorizado(int vehiculoId, int conductorId) =>
        !parametros.exigirParAutorizado || (autorizados[vehiculoId]?.contains(conductorId) ?? false);

    final servicios = [...datos.servicios]..sort((a, b) {
        final porHora = a.horaSolicitada.compareTo(b.horaSolicitada);
        return porHora != 0 ? porHora : a.codigo.compareTo(b.codigo);
      });

    final serviciosTurno = <ServicioTurno>[];
    for (final servicio in servicios) {
      final ruta = rutas[servicio.rutaId];
      final candidatas = ruta == null || !ruta.activa
          ? const <SalidaAutorizada>[]
          : _salidasCandidatas(servicio, salidasPorRuta[ruta.id] ?? const []);
      final compatibles = ruta?.vehiculosCompatibles.toSet() ?? const <int>{};
      // Q_v ≥ q_s y κ(v, r(s)) = 1.
      bool elegible(Vehiculo v) => v.capacidad >= servicio.capacidadRequerida && compatibles.contains(v.id);

      // v ∈ {v0(s), v1(s)}: la unidad que corresponde según su turno en la
      // cola, si sigue en ella, y la siguiente unidad elegible de la cola.
      final entrada = switch (servicio.entradaColaId) {
        final id? => entradas[id],
        null => null,
      };
      int? siguiente;
      if (entrada != null && parametros.permitirSiguienteUnidad) {
        for (final e in activasPorRuta[entrada.rutaId] ?? const <EntradaCola>[]) {
          final v = operativas[e.vehiculoId];
          if (e.posicion > entrada.posicion && e.vehiculoId != entrada.vehiculoId && v != null && elegible(v)) {
            siguiente = e.vehiculoId;
            break;
          }
        }
      }
      final permitidos = entrada == null ? null : {if (entrada.activa) entrada.vehiculoId, ?siguiente};

      final alternativas = <Alternativa>[];
      if (ruta != null && ruta.activa) {
        for (final salida in candidatas) {
          final h = salida.hora;
          final d = salida.duracionMin ?? ruta.duracionMin;
          for (final v in vehiculos) {
            if (!elegible(v) || !(permitidos?.contains(v.id) ?? true)) continue;
            for (final c in conductores) {
              // λ(c, v) = 1, c ∈ {chab(v)} ∪ C_v^R y [t, t + d] ⊆ T_c.
              if (!parametros.habilita(c.categoriaLicencia, v.categoria)) continue;
              if (!autorizado(v.id, c.id)) continue;
              if (h < c.turnoInicio || h + d > c.turnoFin) continue;
              alternativas.add(Alternativa(
                vehiculoId: v.id,
                conductorId: c.id,
                salida: h,
                duracion: d,
              ));
            }
          }
        }
      }
      serviciosTurno.add(ServicioTurno(
        servicioId: servicio.id,
        codigo: servicio.codigo,
        codigoRuta: ruta?.codigo ?? '?',
        prioridad: servicio.prioridad,
        capacidadRequerida: servicio.capacidadRequerida,
        alternativas: alternativas,
        comprometida: datos.comprometidas[servicio.id],
        nominal: servicio.horaSolicitada,
        vehiculoCola: entrada?.vehiculoId,
        posicionCola: entrada?.posicion,
        vehiculoSiguiente: siguiente,
        motivoSinAlternativas: alternativas.isEmpty
            ? _diagnosticar(
                servicio,
                ruta,
                candidatas,
                vehiculos,
                conductores,
                entrada: entrada,
                permitidos: permitidos,
                autorizados: autorizados,
                codigos: {for (final v in datos.vehiculos) v.id: v.codigo},
              )
            : null,
      ));
    }

    final comprometidos = serviciosTurno.where((s) => s.comprometida != null).length;
    return InstanciaTurno(
      fecha: datos.fecha,
      servicios: serviciosTurno,
      conductores: {
        for (final c in conductores)
          c.id: ConductorTurno(
            id: c.id,
            codigo: c.codigo,
            acumulado: c.minutosAcumulados,
            limite: c.limiteMinutos,
          ),
      },
      codigosVehiculo: {for (final v in datos.vehiculos) v.id: v.codigo},
      codigosConductor: {for (final c in datos.conductores) c.id: c.codigo},
      habituales: habituales,
      holguraMinima: parametros.holguraMinima,
      pesos: parametros.pesos,
      referencias: ReferenciasPerdida(
        retraso: parametros.referenciaRetrasoMin,
        reprogramacion: comprometidos == 0 ? 1 : comprometidos.toDouble(),
        tiempoMuerto: parametros.referenciaTiempoMuertoPorVehiculoMin *
            (vehiculos.isEmpty ? 1 : vehiculos.length),
        desequilibrio: parametros.referenciaDesequilibrioMin,
      ),
      penalizacion: parametros.penalizacion,
    );
  }

  /// `H_s`: salidas autorizadas de la ruta desde la hora solicitada hasta la
  /// hora solicitada más la tolerancia.
  List<SalidaAutorizada> _salidasCandidatas(
    ServicioProgramado servicio,
    List<SalidaAutorizada> salidasRuta,
  ) =>
      [
        for (final s in salidasRuta)
          if (s.hora >= servicio.horaSolicitada &&
              s.hora <= servicio.horaSolicitada + parametros.toleranciaSalidaMin)
            s,
      ];

  /// Explica por qué `A_s = ∅`, siguiendo el orden de las condiciones de la
  /// ecuación (1).
  String _diagnosticar(
    ServicioProgramado servicio,
    Ruta? ruta,
    List<SalidaAutorizada> candidatas,
    List<Vehiculo> operativos,
    List<Conductor> disponibles, {
    required EntradaCola? entrada,
    required Set<int>? permitidos,
    required Map<int, Set<int>> autorizados,
    required Map<int, String> codigos,
  }) {
    if (ruta == null) return 'La ruta del servicio no existe';
    if (!ruta.activa) return 'La ruta ${ruta.codigo} está inactiva';
    if (candidatas.isEmpty) {
      return 'No hay salidas autorizadas de ${ruta.codigo} entre '
          '${minutosAHora(servicio.horaSolicitada)} y '
          '${minutosAHora(servicio.horaSolicitada + parametros.toleranciaSalidaMin)}';
    }
    final compatibles = ruta.vehiculosCompatibles.toSet();
    if (compatibles.isEmpty) return 'La ruta ${ruta.codigo} no tiene vehículos compatibles';
    final compatiblesOperativos = operativos.where((v) => compatibles.contains(v.id)).toList();
    if (compatiblesOperativos.isEmpty) {
      return 'Los vehículos compatibles con ${ruta.codigo} no están operativos '
          '(en mantenimiento o inactivos)';
    }
    var conCapacidad =
        compatiblesOperativos.where((v) => v.capacidad >= servicio.capacidadRequerida).toList();
    if (conCapacidad.isEmpty) {
      return 'Ningún vehículo compatible y operativo tiene ${servicio.capacidadRequerida} asientos';
    }
    if (entrada != null && permitidos != null) {
      conCapacidad = [for (final v in conCapacidad) if (permitidos.contains(v.id)) v];
      if (conCapacidad.isEmpty) {
        final unidad = codigos[entrada.vehiculoId] ?? '${entrada.vehiculoId}';
        final estado = entrada.activa ? 'no está disponible para el servicio' : 'dejó la cola';
        final siguiente = parametros.permitirSiguienteUnidad
            ? 'no hay otra unidad elegible después de ella en la cola de ${ruta.codigo}'
            : 'la regla de despacho no admite la siguiente unidad de la cola';
        return 'La unidad que corresponde en la cola ($unidad, posición ${entrada.posicion}) '
            '$estado y $siguiente';
      }
    }
    final unidades = conCapacidad.map((v) => v.codigo).join(', ');
    if (parametros.exigirParAutorizado && conCapacidad.every((v) => autorizados[v.id]?.isEmpty ?? true)) {
      return 'La unidad $unidades no tiene conductor habitual ni reemplazos autorizados registrados';
    }
    final habilitados = disponibles
        .where((c) => conCapacidad.any((v) =>
            parametros.habilita(c.categoriaLicencia, v.categoria) &&
            (!parametros.exigirParAutorizado || (autorizados[v.id]?.contains(c.id) ?? false))))
        .toList();
    if (habilitados.isEmpty) {
      return parametros.exigirParAutorizado
          ? 'Ningún conductor autorizado de $unidades (habitual o reemplazo) está disponible '
              'con licencia vigente y habilitante'
          : 'No hay conductores disponibles con licencia vigente y habilitante';
    }
    return 'Ningún conductor habilitado tiene un turno que cubra el servicio';
  }
}
