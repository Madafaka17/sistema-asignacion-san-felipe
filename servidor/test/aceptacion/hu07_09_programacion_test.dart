import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

import '../apoyo/entorno.dart';
import '../apoyo/escenario.dart';

/// HU-07, HU-08 y HU-09: generación, visualización, ajuste y aprobación de
/// la programación (caso de uso principal; Figura 5 de la tesis).
void main() {
  late Entorno entorno;

  setUpAll(() async => entorno = await Entorno.iniciar());
  setUp(() => entorno.reiniciar());
  tearDownAll(() => entorno.cerrar());

  group('HU-07 Generación de la propuesta', () {
    test('(feliz) 7 servicios, 3 vehículos y 3 conductores: los 7 asignados en ≤ 300 s y Φ = 0', () async {
      await entorno.turnoBase();
      final r = await entorno.generar();
      expect(r.estado, 201);
      final p = Programacion.fromJson(r.mapa);
      expect(p.estado, EstadoProgramacion.propuesta);
      expect(p.metodo, 'algoritmo_genetico');
      expect(p.asignaciones, hasLength(7));
      expect(p.asignaciones.every((a) => a.estado == EstadoAsignacion.asignado), isTrue);
      expect(p.phi, 0);
      expect(p.phiValidador, 0, reason: 'validador independiente (RNF-01)');
      expect(p.tiempoMs, lessThan(300000), reason: 'RNF-02');
      expect(p.historial, isNotEmpty, reason: 'curva de convergencia por generación');

      // Lo mismo quedó registrado en MySQL, con la copia de los parámetros.
      final fila = (await entorno.consultar('SELECT phi_validador, metodo, parametros FROM programacion WHERE id = :id', {'id': p.id})).single;
      expect(fila.entero('phi_validador'), 0);
      expect(fila.texto('parametros'), contains('tamano_poblacion'));
      final asignadas = (await entorno.consultar(
        "SELECT COUNT(*) AS n FROM asignacion WHERE programacion_id = :id AND estado = 'asignado'",
        {'id': p.id},
      ))
          .single;
      expect(asignadas.entero('n'), 7);
    });

    test('(alterno) un servicio sin alternativas admisibles queda como incidencia pendiente; los otros 7 se asignan', () async {
      await entorno.turnoBase();
      final v04 = await entorno.vehiculo('V-04', 'AHK-104', estado: 'mantenimiento');
      final r04 = await entorno.ruta('R-04', 60, [v04], salidas: ['07:00']);
      await entorno.servicio('S-108', r04, '07:00', prioridad: 3);

      final r = await entorno.generar();
      expect(r.estado, 201);
      final p = Programacion.fromJson(r.mapa);
      expect(p.asignaciones, hasLength(8));
      expect(p.asignados, 7);
      final s108 = p.asignaciones.singleWhere((a) => a.codigoServicio == 'S-108');
      expect(s108.estado, EstadoAsignacion.incidencia);
      expect(s108.motivo, contains('no están operativos'));
      expect(p.asignaciones.any((a) => a.vehiculoId == v04), isFalse, reason: 'no asigna recursos no disponibles');
      expect(p.phiValidador, 0);
    });

    test('(error) turno sin servicios pendientes: no ejecuta el método', () async {
      final r = await entorno.generar();
      expect(r.estado, 422);
      expect(r.mensajeError, 'No hay servicios pendientes para el turno seleccionado');
      expect((await entorno.consultar('SELECT COUNT(*) AS n FROM programacion')).single.entero('n'), 0);
    });

    test('con la misma semilla y los mismos datos la propuesta es la misma (reproducibilidad)', () async {
      await entorno.turnoBase();
      final a = Programacion.fromJson((await entorno.generar()).mapa);
      final b = Programacion.fromJson((await entorno.generar()).mapa);
      String firma(Programacion p) => [for (final x in p.asignaciones) '${x.servicioId}:${x.vehiculoId}:${x.conductorId}:${x.salida}'].join(',');
      expect(firma(b), firma(a));
      expect(b.id, isNot(a.id), reason: 'cada ejecución es un registro nuevo');
    });
  });

  group('HU-08 Visualización de la propuesta', () {
    test('(feliz) cada servicio muestra vehículo, conductor, ruta, salida y término, ordenados por salida', () async {
      await entorno.turnoBase();
      final generada = await entorno.generar();
      final r = await entorno.get('/api/programaciones/${generada.mapa['id']}', como: 'operaciones');
      expect(r.estado, 200);
      final asignaciones = asignacionesDe(r);
      for (final a in asignaciones) {
        expect(a, allOf(
          containsPair('codigoVehiculo', isA<String>()),
          containsPair('codigoConductor', isA<String>()),
          containsPair('codigoRuta', isA<String>()),
          containsPair('salida', isA<int>()),
          containsPair('fin', isA<int>()),
        ));
      }
      final salidas = [for (final a in asignaciones) a['salida'] as int];
      expect(salidas, orderedEquals([...salidas]..sort()));
    });

    test('(alterno) el servicio con incidencia aparece al inicio con su motivo', () async {
      await entorno.turnoBase();
      final v04 = await entorno.vehiculo('V-04', 'AHK-104', estado: 'mantenimiento');
      final r04 = await entorno.ruta('R-04', 60, [v04], salidas: ['15:00']);
      await entorno.servicio('S-108', r04, '15:00');
      final generada = await entorno.generar();
      final r = await entorno.get('/api/programaciones/${generada.mapa['id']}', como: 'operaciones');
      final primera = asignacionesDe(r).first;
      expect(primera['codigoServicio'], 'S-108');
      expect(primera['estado'], 'incidencia');
      expect(primera['motivo'], isNotEmpty);
    });
  });

  group('HU-09 Aprobación y ajuste', () {
    test('(feliz) la aprobación queda en la bitácora y una nueva ejecución no la modifica', () async {
      await entorno.turnoBase();
      final propuesta = Programacion.fromJson((await entorno.generar()).mapa);

      final r = await entorno.post('/api/programaciones/${propuesta.id}/aprobar', null, como: 'operaciones');
      expect(r.estado, 200, reason: '$r');
      final aprobada = Programacion.fromJson(r.mapa);
      expect(aprobada.estado, EstadoProgramacion.aprobada);
      expect(aprobada.aprobadoPor, 'operaciones');
      expect(aprobada.aprobadoEn, Entorno.hoy);

      final eventos = await entorno.consultar(
        "SELECT u.nombre_usuario, b.fecha_hora FROM bitacora b JOIN usuario u ON u.id = b.usuario_id "
        "WHERE b.accion = 'aprobar_programacion' AND b.entidad_id = :id",
        {'id': propuesta.id},
      );
      expect(eventos.single.texto('nombre_usuario'), 'operaciones');

      // Los servicios asignados pasan a «programado».
      final pendientes = await entorno.consultar("SELECT COUNT(*) AS n FROM servicio WHERE estado = 'pendiente'");
      expect(pendientes.single.entero('n'), 0);

      // Una nueva ejecución no la modifica.
      expect((await entorno.generar()).estado, 422);
      final releida = Programacion.fromJson((await entorno.get('/api/programaciones/${propuesta.id}', como: 'operaciones')).mapa);
      expect(releida.estado, EstadoProgramacion.aprobada);
      expect(releida.asignaciones.map((a) => a.toJson()), aprobada.asignaciones.map((a) => a.toJson()));
    });

    test('(alterno) ajuste válido: cambiar el conductor de S-115 de C-12 a C-08 se acepta y se registra', () async {
      final v07 = await entorno.vehiculo('V-07', 'ABC-123');
      final c12 = await entorno.conductor('C-12', '70000012');
      final ruta = await entorno.ruta('R-03', 95, [v07], salidas: ['07:30']);
      await entorno.servicio('S-115', ruta, '07:30', prioridad: 3);
      final propuesta = Programacion.fromJson((await entorno.generar()).mapa);
      final s115 = propuesta.asignaciones.single;
      expect(s115.conductorId, c12);

      // C-08 se registra después y está libre en ese horario.
      final c08 = await entorno.conductor('C-08', '70000008');
      final r = await entorno.put(
        '/api/programaciones/${propuesta.id}/asignaciones/${s115.servicioId}',
        AjusteAsignacion(vehiculoId: v07, conductorId: c08, salida: 450).toJson(),
        como: 'operaciones',
      );
      expect(r.estado, 200, reason: '$r');
      final ajustada = Programacion.fromJson(r.mapa).asignaciones.single;
      expect(ajustada.conductorId, c08);
      expect(ajustada.ajustada, isTrue);
      expect(ajustada.estado, EstadoAsignacion.asignado);

      final evento = (await entorno.consultar("SELECT detalle FROM bitacora WHERE accion = 'ajustar_asignacion'")).single;
      expect(evento.texto('detalle'), contains('S-115'));
      expect((await entorno.post('/api/programaciones/${propuesta.id}/aprobar', null, como: 'operaciones')).estado, 200);
    });

    test('(error) ajuste con conflicto: V-07 en S-120 y S-115 superpuestos impide aprobar', () async {
      final v07 = await entorno.vehiculo('V-07', 'ABC-123');
      final v08 = await entorno.vehiculo('V-08', 'ABC-124');
      await entorno.conductor('C-12', '70000012');
      final c08 = await entorno.conductor('C-08', '70000008');
      final ruta = await entorno.ruta('R-03', 95, [v07, v08], salidas: ['07:30', '08:00']);
      await entorno.servicio('S-115', ruta, '07:30', prioridad: 3);
      await entorno.servicio('S-120', ruta, '08:00');
      final propuesta = Programacion.fromJson((await entorno.generar()).mapa);
      expect(propuesta.phiValidador, 0);
      final s115 = propuesta.asignaciones.singleWhere((a) => a.codigoServicio == 'S-115');
      final s120 = propuesta.asignaciones.singleWhere((a) => a.codigoServicio == 'S-120');

      // S-115 ocupa a V-07 de 07:30 a 09:05; S-120 sale a las 08:00.
      final vehiculoS115 = s115.vehiculoId!;
      final conductorS120 = s120.conductorId == s115.conductorId ? c08 : s120.conductorId!;
      final r = await entorno.put(
        '/api/programaciones/${propuesta.id}/asignaciones/${s120.servicioId}',
        AjusteAsignacion(vehiculoId: vehiculoS115, conductorId: conductorS120, salida: 480).toJson(),
        como: 'operaciones',
      );
      expect(r.estado, 200, reason: 'el ajuste se guarda, pero marcado como cruce: $r');
      final conCruce = Programacion.fromJson(r.mapa);
      expect(conCruce.phiValidador, greaterThan(0));
      final marcadas = conCruce.asignaciones.where((a) => a.estado == EstadoAsignacion.conflicto).map((a) => a.codigoServicio);
      expect(marcadas, unorderedEquals(['S-115', 'S-120']));

      final aprobar = await entorno.post('/api/programaciones/${propuesta.id}/aprobar', null, como: 'operaciones');
      expect(aprobar.estado, 409);
      expect(aprobar.mensajeError, allOf(contains('cruces sin resolver'), contains('S-115'), contains('S-120')));
      final estado = (await entorno.consultar('SELECT estado FROM programacion WHERE id = :id', {'id': propuesta.id})).single;
      expect(estado.texto('estado'), 'propuesta');
    });

    test('un ajuste fuera de las alternativas admisibles se rechaza (422)', () async {
      await entorno.turnoBase();
      final propuesta = Programacion.fromJson((await entorno.generar()).mapa);
      final a = propuesta.asignaciones.first;
      final r = await entorno.put(
        '/api/programaciones/${propuesta.id}/asignaciones/${a.servicioId}',
        AjusteAsignacion(vehiculoId: a.vehiculoId!, conductorId: a.conductorId!, salida: a.salida! + 1).toJson(),
        como: 'operaciones',
      );
      expect(r.estado, 422);
    });
  });
}
