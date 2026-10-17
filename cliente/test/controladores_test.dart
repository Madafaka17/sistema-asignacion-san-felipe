import 'package:cliente/controladores/operacion_controladores.dart';
import 'package:cliente/controladores/registros_controladores.dart';
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

  group('Cola de despacho (sección 3.1.2)', () {
    const moyobamba = Ruta(id: 1, codigo: 'R-01', origen: 'Soritor', destino: 'Moyobamba', duracionMin: 90, vehiculosCompatibles: [1, 2]);
    const inactiva = Ruta(id: 2, codigo: 'R-02', origen: 'Soritor', destino: 'Tarapoto', duracionMin: 330, activa: false);
    final flota = [
      const Vehiculo(id: 1, codigo: 'V-01', placa: 'AHK-101', capacidad: 16, categoria: CategoriaVehiculo.m2),
      const Vehiculo(id: 2, codigo: 'V-02', placa: 'AHK-102', capacidad: 16, categoria: CategoriaVehiculo.m2, estado: EstadoVehiculo.mantenimiento),
      const Vehiculo(id: 3, codigo: 'V-03', placa: 'AHK-103', capacidad: 16, categoria: CategoriaVehiculo.m2),
    ];

    test('la cola de la primera ruta activa se carga y las llegadas se agregan al final', () async {
      final cola = _Cola([
        EntradaCola(id: 1, rutaId: 1, fecha: DateTime.utc(2026, 11, 12), vehiculoId: 1, posicion: 1, llegada: 320, codigoVehiculo: 'V-01'),
      ]);
      final c = ColaControlador(cola, _Rutas([inactiva, moyobamba]), _Vehiculos(flota), hoy: DateTime(2026, 11, 11));
      await c.cargar();
      expect(c.ruta?.codigo, 'R-01');
      expect(c.entradas.single.codigoVehiculo, 'V-01');
      expect(c.unidadesElegibles.map((v) => v.codigo), ['V-01'], reason: 'V-02 en mantenimiento y V-03 incompatible');

      expect(await c.registrarLlegada(1, 450), isTrue);
      expect(cola.solicitudes.single.toJson(), {'rutaId': 1, 'fecha': '2026-11-12', 'vehiculoId': 1, 'llegada': 450});
      expect([for (final e in c.entradas) e.posicion], [1, 2]);

      expect(await c.retirar(c.entradas.first), isTrue);
      expect([for (final e in c.entradas) e.activa], [false, true]);
      expect(c.enEspera, 1);
    });

    test('el formulario de servicios ofrece solo turnos libres que llegan antes de la salida', () async {
      final fecha = DateTime.utc(2026, 11, 12);
      final c = ServiciosControlador(
        _Servicios(),
        _Rutas([moyobamba]),
        _Cola([
          EntradaCola(id: 1, rutaId: 1, fecha: fecha, vehiculoId: 1, posicion: 1, llegada: 320, servicioId: 7),
          EntradaCola(id: 2, rutaId: 1, fecha: fecha, vehiculoId: 2, posicion: 2, llegada: 325, activa: false),
          EntradaCola(id: 3, rutaId: 1, fecha: fecha, vehiculoId: 3, posicion: 3, llegada: 330),
          EntradaCola(id: 4, rutaId: 1, fecha: fecha, vehiculoId: 1, posicion: 4, llegada: 480),
        ]),
        hoy: DateTime(2026, 11, 11),
      );
      await c.cargarRuta(1);
      expect(c.salidasDe(1).map((s) => s.hora), [360, 450]);
      expect([for (final e in c.turnosDisponibles(1, 450)) e.id], [3]);
      expect([for (final e in c.turnosDisponibles(1, 480)) e.id], [3, 4]);
      expect([for (final e in c.turnosDisponibles(1, 450, servicioId: 7)) e.id], [1, 3], reason: 'al editar, su propio turno');
    });
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
  _Vehiculos([this._flota = const []]);

  final List<Vehiculo> _flota;

  @override
  Future<List<Vehiculo>> listar() async => _flota;

  @override
  Future<Vehiculo> crear(Vehiculo vehiculo) async => vehiculo;

  @override
  Future<Vehiculo> actualizar(Vehiculo vehiculo) async => vehiculo;

  @override
  Future<List<ParAutorizado>> pares() async => const [];

  @override
  Future<ConductoresAutorizados> asignarConductores(ConductoresAutorizados autorizados) async => autorizados;
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

class _Rutas implements RepositorioRutas {
  _Rutas(this._rutas);

  final List<Ruta> _rutas;

  @override
  Future<List<Ruta>> listar() async => _rutas;

  @override
  Future<List<SalidaAutorizada>> salidas(int rutaId) async =>
      [for (final h in [360, 450]) SalidaAutorizada(id: h, rutaId: rutaId, hora: h)];

  @override
  Future<Ruta> crear(Ruta ruta) async => ruta;

  @override
  Future<Ruta> actualizar(Ruta ruta) async => ruta;

  @override
  Future<SalidaAutorizada> crearSalida(int rutaId, int hora, {int? duracionMin}) async => throw UnimplementedError();

  @override
  Future<void> eliminarSalida(int id) async {}
}

class _Servicios implements RepositorioServicios {
  @override
  Future<List<ServicioProgramado>> listar(DateTime fecha) async => const [];

  @override
  Future<ServicioProgramado> crear(ServicioProgramado servicio) async => servicio;

  @override
  Future<ServicioProgramado> actualizar(ServicioProgramado servicio) async => servicio;

  @override
  Future<ServicioProgramado> cancelar(int id) async => throw UnimplementedError();
}

/// Cola en memoria: cada llegada recibe la posición siguiente, como en el
/// servidor.
class _Cola implements RepositorioCola {
  _Cola(List<EntradaCola> entradas) : _entradas = [...entradas];

  final List<EntradaCola> _entradas;
  final solicitudes = <SolicitudEntradaCola>[];

  @override
  Future<List<EntradaCola>> entradas(DateTime fecha, {int? rutaId}) async =>
      [for (final e in _entradas) if (rutaId == null || e.rutaId == rutaId) e];

  @override
  Future<EntradaCola> registrar(SolicitudEntradaCola s) async {
    solicitudes.add(s);
    final nueva = EntradaCola(
      id: _entradas.length + 1,
      rutaId: s.rutaId,
      fecha: s.fecha,
      vehiculoId: s.vehiculoId,
      posicion: _entradas.length + 1,
      llegada: s.llegada,
    );
    _entradas.add(nueva);
    return nueva;
  }

  @override
  Future<EntradaCola> retirar(int id) async {
    final e = _entradas.firstWhere((e) => e.id == id);
    return EntradaCola(
      id: e.id,
      rutaId: e.rutaId,
      fecha: e.fecha,
      vehiculoId: e.vehiculoId,
      posicion: e.posicion,
      llegada: e.llegada,
      activa: false,
      codigoVehiculo: e.codigoVehiculo,
    );
  }
}
