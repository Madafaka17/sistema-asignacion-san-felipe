import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

import '../apoyo/entorno.dart';
import '../apoyo/escenario.dart';

/// Procedencia y versiones (sección 5.5, CU-07, CU-09 y CU-12 y Tabla 48 de
/// la tesis): snapshot inmutable de la entrada con su huella, versión del
/// algoritmo, versión de cada ajuste, versión esperada al aprobar y tiempo
/// del núcleo separado del de la API.
void main() {
  late Entorno entorno;

  setUpAll(() async => entorno = await Entorno.iniciar());
  setUp(() => entorno.reiniciar());
  tearDownAll(() => entorno.cerrar());

  Future<Programacion> generada() async {
    final r = await entorno.generar();
    expect(r.estado, 201, reason: '$r');
    return Programacion.fromJson(r.mapa);
  }

  Future<Respuesta> aprobar(int id) => entorno.post('/api/programaciones/$id/aprobar', null, como: 'operaciones');

  /// Ajusta la primera asignación: con [mover], a otra salida admisible de
  /// su ventana (puede dejar cruces); si no, confirma la misma alternativa,
  /// lo que crea igualmente una versión nueva. Lleva motivo porque la
  /// salida puede estar demorada.
  Future<Respuesta> ajustar(Programacion p, {bool mover = false}) {
    final a = p.asignaciones.firstWhere((a) => a.tieneRecursos);
    final nominal = a.salida! - a.demoraMin;
    return entorno.put(
      '/api/programaciones/${p.id}/asignaciones/${a.servicioId}',
      AjusteAsignacion(
        vehiculoId: a.vehiculoId!,
        conductorId: a.conductorId!,
        salida: !mover ? a.salida! : (a.salida == nominal ? nominal + 30 : nominal),
        justificacion: 'Prueba de versiones',
      ).toJson(),
      como: 'operaciones',
    );
  }

  test('la ejecución guarda el snapshot de su entrada con SHA-256 y se repite desde él', () async {
    await entorno.turnoBase();
    final p = await generada();
    expect(p.huellaEntrada, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(p.versionAlgoritmo, 'algoritmo_genetico@$versionNucleo');
    expect((p.version, p.ejecucionId, p.versionAnteriorId), (1, p.id, null));
    expect(p.tiempoNucleoMs, lessThanOrEqualTo(p.tiempoMs), reason: 'el núcleo es parte de la solicitud');

    final r = await entorno.get('/api/programaciones/${p.id}/entrada', como: 'operaciones');
    expect(r.estado, 200, reason: '$r');
    final snapshot = SnapshotEntrada.fromJson(r.mapa);
    expect(snapshot.sha256, p.huellaEntrada);
    expect(sha256.convert(utf8.encode(jsonCanonico(snapshot.contenido))).toString(), snapshot.sha256);
    final enBase =
        (await entorno.consultar('SELECT SHA2(contenido, 256) = sha256 AS coincide FROM snapshot_entrada')).single;
    expect(enBase.booleano('coincide'), isTrue);

    // Con el snapshot, la semilla y los parámetros guardados, el núcleo
    // vuelve a dar la misma propuesta.
    final datos = DatosTurno.fromJson(snapshot.contenido);
    final instancia = ConstructorInstancia(Entorno.parametros.modelo).construir(datos);
    final repetida = AlgoritmoGenetico(Entorno.parametros.algoritmoGenetico.conSemilla(p.semilla!)).resolver(instancia);
    expect(repetida.evaluacion.aptitud, closeTo(p.aptitud, 1e-9));
    expect(repetida.generaciones, p.generaciones);

    // La misma entrada no crea otro snapshot.
    final otra = await generada();
    expect(otra.huellaEntrada, p.huellaEntrada);
    expect((await entorno.consultar('SELECT COUNT(*) AS n FROM snapshot_entrada')).single.entero('n'), 1);
  });

  test('cada ajuste crea una versión y conserva la anterior; una versión sustituida no se ajusta ni se aprueba',
      () async {
    await entorno.turnoBase();
    final v1 = await generada();
    final r = await ajustar(v1, mover: true);
    expect(r.estado, 200, reason: '$r');
    final v2 = Programacion.fromJson(r.mapa);
    expect(
        (v2.version, v2.versionAnteriorId, v2.ejecucionId, v2.estado), (2, v1.id, v1.id, EstadoProgramacion.propuesta));
    expect(v2.historial.length, v1.historial.length, reason: 'la curva es de la ejecución');
    expect(v2.huellaEntrada, v1.huellaEntrada, reason: 'la entrada no cambió entre la generación y el ajuste');

    final original =
        Programacion.fromJson((await entorno.get('/api/programaciones/${v1.id}', como: 'operaciones')).mapa);
    expect(original.estado, EstadoProgramacion.sustituida);
    expect(
      [for (final a in original.asignaciones) (a.servicioId, a.vehiculoId, a.conductorId, a.salida)],
      [for (final a in v1.asignaciones) (a.servicioId, a.vehiculoId, a.conductorId, a.salida)],
      reason: 'la versión original permanece sin cambios',
    );

    final otraVez = await ajustar(v1);
    expect(otraVez.estado, 409);
    expect(otraVez.mensajeError,
        'Esta versión fue sustituida por un ajuste (versión 2, programación #${v2.id}): revise la versión vigente');
    expect((await aprobar(v1.id)).estado, 409);

    final versiones = (await entorno.get('/api/programaciones?fecha=${Entorno.turno}', como: 'operaciones')).lista;
    expect([
      for (final p in versiones) ((p as Map)['id'], p['version'], p['estado'])
    ], [
      (v2.id, 2, 'propuesta'),
      (v1.id, 1, 'sustituida'),
    ]);
    final evento =
        (await entorno.consultar("SELECT entidad_id, detalle FROM bitacora WHERE accion = 'ajustar_asignacion'"))
            .single;
    expect(evento.entero('entidad_id'), v2.id);
    expect((evento.json('detalle') as Map)['versionAnterior'], v1.id);
  });

  test('dos aprobaciones o dos ajustes simultáneos de la misma versión: solo uno se registra', () async {
    await entorno.turnoBase();
    final p = await generada();
    final ajustes = await Future.wait([ajustar(p), ajustar(p)]);
    expect([for (final r in ajustes) r.estado]..sort(), [200, 409]);
    final vigente = Programacion.fromJson(ajustes.firstWhere((r) => r.estado == 200).mapa);

    final aprobaciones = await Future.wait([aprobar(vigente.id), aprobar(vigente.id)]);
    expect([for (final r in aprobaciones) r.estado]..sort(), [200, 422]);
    final eventos = await entorno.consultar("SELECT COUNT(*) AS n FROM bitacora WHERE accion = 'aprobar_programacion'");
    expect(eventos.single.entero('n'), 1);
    final evento =
        (await entorno.consultar("SELECT detalle FROM bitacora WHERE accion = 'aprobar_programacion'")).single;
    final detalle = evento.json('detalle') as Map;
    expect((detalle['version'], detalle['huellaEntrada']), (2, p.huellaEntrada));
  });

  test('el reporte separa el tiempo del núcleo y no cuenta los ajustes como ejecuciones', () async {
    await entorno.turnoBase();
    final p = await generada();
    final v2 = Programacion.fromJson((await ajustar(p)).mapa);
    expect((await aprobar(v2.id)).estado, 200);

    final r = await entorno.get('/api/reportes/indicadores?desde=${Entorno.turno}&hasta=${Entorno.turno}',
        como: 'operaciones');
    final reporte = ReporteIndicadores.fromJson(r.mapa);
    expect(reporte.programacionesGeneradas, 1);
    expect(reporte.tiempoNucleoPromedioS, lessThanOrEqualTo(reporte.tiempoGeneracionPromedioS));
    expect(reporte.tiempoNucleoPromedioS, closeTo(p.tiempoNucleoMs / 1000, 1e-9));
    final csv = await entorno.get('/api/reportes/indicadores.csv?desde=${Entorno.turno}&hasta=${Entorno.turno}',
        como: 'operaciones');
    expect(csv.texto, contains('Tiempo medio del núcleo de optimización'));
  });
}
