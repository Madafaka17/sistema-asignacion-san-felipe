import 'package:cliente/controladores/operacion_controladores.dart';
import 'package:cliente/modelo/repositorios/operacion_repositorio.dart';
import 'package:cliente/modelo/repositorios/registros_repositorio.dart';
import 'package:dominio/dominio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los controladores se prueban con repositorios en memoria: no hay HTTP ni
/// base de datos en la capa de controladores.
void main() {
  Asignacion asignacion(String codigo, int? salida, EstadoAsignacion estado) => Asignacion(
        servicioId: codigo.hashCode,
        codigoServicio: codigo,
        codigoRuta: 'R-01',
        prioridad: 2,
        vehiculoId: salida == null ? null : 1,
        codigoVehiculo: salida == null ? null : 'V-01',
        conductorId: salida == null ? null : 1,
        codigoConductor: salida == null ? null : 'C-01',
        salida: salida,
        fin: salida == null ? null : salida + 50,
        estado: estado,
        motivo: estado == EstadoAsignacion.incidencia ? 'Sin alternativas admisibles' : null,
      );

  Programacion programacion({int phi = 0, List<Asignacion>? asignaciones}) => Programacion(
        id: 7,
        fecha: DateTime.utc(2026, 11, 12),
        estado: EstadoProgramacion.propuesta,
        metodo: 'algoritmo_genetico',
        aptitud: -0.2,
        phi: phi,
        phiValidador: phi,
        componentes: const ComponentesAptitud(),
        generaciones: 30,
        tiempoMs: 120,
        semilla: 1,
        creadoPor: 'operaciones',
        creadoEn: DateTime.utc(2026, 11, 11, 10),
        asignaciones: asignaciones ??
            [
              asignacion('S-103', 480, EstadoAsignacion.asignado),
              asignacion('S-101', 360, EstadoAsignacion.asignado),
              asignacion('S-108', null, EstadoAsignacion.incidencia),
            ],
        historial: const [],
      );

  test('HU-08: las incidencias aparecen primero y luego por hora de salida', () async {
    final c = ProgramacionControlador(_Programaciones(programacion()), _Vehiculos(), _Conductores(), hoy: DateTime(2026, 11, 11));
    await c.generar();
    expect([for (final a in c.asignaciones) a.codigoServicio], ['S-108', 'S-101', 'S-103']);
    expect(c.fecha, DateTime.utc(2026, 11, 12), reason: 'por defecto, el turno del día siguiente');
    expect(c.mensaje, contains('1 con incidencia'));
  });

  test('HU-09: no se puede aprobar mientras el validador reporte cruces', () async {
    final c = ProgramacionControlador(_Programaciones(programacion(phi: 2)), _Vehiculos(), _Conductores());
    await c.generar();
    expect(c.puedeAprobar, isFalse);
    final sinCruces = ProgramacionControlador(_Programaciones(programacion()), _Vehiculos(), _Conductores());
    await sinCruces.generar();
    expect(sinCruces.puedeAprobar, isTrue);
  });

  test('al volver a la pantalla carga el detalle de la última ejecución, no solo el resumen', () async {
    final completa = programacion();
    final repositorio = _Programaciones(completa, resumenSinDetalle: true);
    final c = ProgramacionControlador(repositorio, _Vehiculos(), _Conductores());
    await c.cargar();
    expect(c.historial.single.asignaciones, isEmpty, reason: 'el listado trae solo el resumen');
    expect(c.asignaciones, hasLength(3));
    expect(repositorio.detallesPedidos, [completa.id]);
  });

  test('un error del servidor queda en el controlador con sus campos y libera el estado ocupado', () async {
    final c = ProgramacionControlador(_Programaciones(null), _Vehiculos(), _Conductores());
    final resultado = await c.generar();
    expect(resultado, isFalse);
    expect(c.error, 'No hay servicios pendientes para el turno seleccionado');
    expect(c.ocupado, isFalse);
  });
}

class _Programaciones implements RepositorioProgramaciones {
  _Programaciones(this._resultado, {this.resumenSinDetalle = false});

  final Programacion? _resultado;
  final bool resumenSinDetalle;
  final detallesPedidos = <int>[];

  @override
  Future<Programacion> generar(DateTime fecha) async =>
      _resultado ?? (throw ExcepcionApi(CodigoError.reglaNegocio, 'No hay servicios pendientes para el turno seleccionado'));

  @override
  Future<List<Programacion>> listar(DateTime fecha) async {
    final p = _resultado;
    if (p == null) return const [];
    if (!resumenSinDetalle) return [p];
    // Como GET /api/programaciones: sin asignaciones ni historial.
    return [Programacion.fromJson({...p.toJson(), 'asignaciones': <Object?>[], 'historial': <Object?>[]})];
  }

  @override
  Future<Programacion> obtener(int id) async {
    detallesPedidos.add(id);
    return _resultado!;
  }

  @override
  Future<Programacion> ajustar(int programacionId, int servicioId, AjusteAsignacion ajuste) async => _resultado!;

  @override
  Future<Programacion> aprobar(int id) async => _resultado!;
}

class _Vehiculos implements RepositorioVehiculos {
  @override
  Future<List<Vehiculo>> listar() async => const [];

  @override
  Future<Vehiculo> crear(Vehiculo vehiculo) async => vehiculo;

  @override
  Future<Vehiculo> actualizar(Vehiculo vehiculo) async => vehiculo;
}

class _Conductores implements RepositorioConductores {
  @override
  Future<List<Conductor>> listar() async => const [];

  @override
  Future<Conductor> crear(Conductor conductor) async => conductor;

  @override
  Future<Conductor> actualizar(Conductor conductor) async => conductor;

  @override
  Future<Conductor> cambiarDisponibilidad(int id, bool disponible) async => throw UnimplementedError();
}
