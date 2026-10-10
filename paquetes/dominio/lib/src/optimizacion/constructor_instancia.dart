import '../modelos/conductor.dart';
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

  /// `b(s)`: id del servicio → alternativa de la programación aprobada.
  final Map<int, Alternativa> comprometidas;
}

/// Construye la instancia del turno: aplica la ecuación (1) para obtener
/// `A_s` y prepara `H_c0`, `H_cmáx`, `w` y `b`.
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
    // E_c(h) = 1: el conductor está disponible, su licencia está vigente en la
    // fecha y aún no agotó su límite de conducción.
    final conductores = datos.conductores
        .where((c) =>
            c.disponible && c.licenciaVigente(datos.fecha) && c.minutosAcumulados < c.limiteMinutos)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

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
      final alternativas = <Alternativa>[];
      if (ruta != null && ruta.activa) {
        final compatibles = ruta.vehiculosCompatibles.toSet();
        for (final salida in candidatas) {
          final h = salida.hora;
          final d = salida.duracionMin ?? ruta.duracionMin;
          for (final v in vehiculos) {
            // Q_v ≥ q_s y κ(v, r(s)) = 1.
            if (v.capacidad < servicio.capacidadRequerida || !compatibles.contains(v.id)) continue;
            for (final c in conductores) {
              // λ(c, v) = 1 y [t, t + d] ⊆ T_c.
              if (!parametros.habilita(c.categoriaLicencia, v.categoria)) continue;
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
        motivoSinAlternativas: alternativas.isEmpty
            ? _diagnosticar(servicio, ruta, candidatas, vehiculos, conductores, datos)
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
      codigosVehiculo: {for (final v in vehiculos) v.id: v.codigo},
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
    List<Conductor> disponibles,
    DatosTurno datos,
  ) {
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
    final conCapacidad =
        compatiblesOperativos.where((v) => v.capacidad >= servicio.capacidadRequerida).toList();
    if (conCapacidad.isEmpty) {
      return 'Ningún vehículo compatible y operativo tiene ${servicio.capacidadRequerida} asientos';
    }
    final habilitados = disponibles
        .where((c) => conCapacidad.any((v) => parametros.habilita(c.categoriaLicencia, v.categoria)))
        .toList();
    if (habilitados.isEmpty) {
      return 'No hay conductores disponibles con licencia vigente y habilitante';
    }
    return 'Ningún conductor habilitado tiene un turno que cubra el servicio';
  }
}
