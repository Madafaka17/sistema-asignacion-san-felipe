import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

void main() {
  final fecha = DateTime.utc(2026, 11, 12);
  const parametros = ParametrosModelo(holguraMinima: 10, toleranciaSalidaMin: 30);

  Vehiculo vehiculo(int id, {int capacidad = 15, EstadoVehiculo estado = EstadoVehiculo.operativo}) =>
      Vehiculo(
        id: id,
        codigo: 'V-0$id',
        placa: 'ABC-10$id',
        capacidad: capacidad,
        categoria: CategoriaVehiculo.m2,
        estado: estado,
      );

  Conductor conductor(
    int id, {
    DateTime? vencimiento,
    int inicio = 360,
    int fin = 960,
    int acumulado = 0,
    int limite = 600,
    bool disponible = true,
    CategoriaLicencia licencia = CategoriaLicencia.aIIb,
  }) =>
      Conductor(
        id: id,
        codigo: 'C-$id',
        dni: '7000000$id',
        nombres: 'Nombre$id',
        apellidos: 'Apellido$id',
        categoriaLicencia: licencia,
        vencimientoLicencia: vencimiento ?? DateTime.utc(2027, 6, 30),
        turnoInicio: inicio,
        turnoFin: fin,
        minutosAcumulados: acumulado,
        limiteMinutos: limite,
        disponible: disponible,
      );

  final ruta = Ruta(
    id: 3,
    codigo: 'R-03',
    origen: 'Soritor',
    destino: 'Moyobamba',
    duracionMin: 95,
    vehiculosCompatibles: const [1, 2],
  );

  ServicioProgramado servicio(int id, String hora, {int capacidad = 10, int prioridad = 2}) =>
      ServicioProgramado(
        id: id,
        codigo: 'S-$id',
        fecha: fecha,
        rutaId: 3,
        horaSolicitada: horaAMinutos(hora)!,
        prioridad: prioridad,
        capacidadRequerida: capacidad,
      );

  final salidas = [
    SalidaAutorizada(id: 1, rutaId: 3, hora: horaAMinutos('07:30')!),
    SalidaAutorizada(id: 2, rutaId: 3, hora: horaAMinutos('07:45')!, duracionMin: 110),
    SalidaAutorizada(id: 3, rutaId: 3, hora: horaAMinutos('08:30')!),
  ];

  InstanciaTurno construir({
    List<ServicioProgramado>? servicios,
    List<Vehiculo>? vehiculos,
    List<Conductor>? conductores,
    Map<int, Alternativa> comprometidas = const {},
  }) =>
      const ConstructorInstancia(parametros).construir(DatosTurno(
        fecha: fecha,
        servicios: servicios ?? [servicio(115, '07:30')],
        vehiculos: vehiculos ?? [vehiculo(1), vehiculo(2)],
        conductores: conductores ?? [conductor(12), conductor(8)],
        rutas: [ruta],
        salidas: salidas,
        comprometidas: comprometidas,
      ));

  test('A_s combina vehículos compatibles, conductores y salidas de H_s', () {
    final s = construir().servicios.single;
    // H_s = {07:30, 07:45} (08:30 queda fuera de la tolerancia de 30 min).
    expect(s.alternativas.map((a) => a.salida).toSet(), {450, 465});
    expect(s.alternativas, hasLength(2 * 2 * 2));
    // Ordenadas por hora de salida, vehículo y conductor.
    expect(s.alternativas.first.salida, 450);
    expect(s.alternativas.first.vehiculoId, 1);
    expect(s.alternativas.first.conductorId, 8);
  });

  test('d_{s,h} usa la duración de la salida si la tiene y si no la de la ruta (HU-04)', () {
    final s = construir().servicios.single;
    expect(s.alternativas.where((a) => a.salida == 450).every((a) => a.duracion == 95), isTrue);
    expect(s.alternativas.where((a) => a.salida == 465).every((a) => a.duracion == 110), isTrue);
  });

  test('una unidad en mantenimiento deja de figurar en las alternativas (HU-02)', () {
    final s = construir(vehiculos: [vehiculo(1), vehiculo(2, estado: EstadoVehiculo.mantenimiento)])
        .servicios
        .single;
    expect(s.alternativas.every((a) => a.vehiculoId == 1), isTrue);
  });

  test('Q_v ≥ q_s: se excluyen los vehículos sin capacidad suficiente', () {
    final s = construir(vehiculos: [vehiculo(1, capacidad: 8), vehiculo(2)]).servicios.single;
    expect(s.alternativas.every((a) => a.vehiculoId == 2), isTrue);
  });

  test('λ(c, v): licencia vencida o no habilitante excluye al conductor (HU-03)', () {
    final s = construir(conductores: [
      conductor(12, vencimiento: DateTime.utc(2026, 9, 15)),
      conductor(8, licencia: CategoriaLicencia.aIIa),
      conductor(5),
    ]).servicios.single;
    expect(s.alternativas.every((a) => a.conductorId == 5), isTrue);
  });

  test('el intervalo del servicio debe caber en el turno T_c del conductor', () {
    // El turno de C-12 termina a las 09:00: la salida de las 07:45 (110 min,
    // hasta las 09:35) no cabe; la de las 07:30 (hasta las 09:05) tampoco.
    final s = construir(conductores: [conductor(12, fin: 540), conductor(8)]).servicios.single;
    expect(s.alternativas.where((a) => a.conductorId == 12), isEmpty);
  });

  test('los vehículos compatibles en mantenimiento dejan el servicio sin alternativas (HU-07)', () {
    final instancia = construir(vehiculos: [
      vehiculo(1, estado: EstadoVehiculo.mantenimiento),
      vehiculo(2, estado: EstadoVehiculo.mantenimiento),
    ]);
    final s = instancia.servicios.single;
    expect(s.tieneAlternativas, isFalse);
    expect(s.motivoSinAlternativas, contains('mantenimiento'));
    expect(instancia.admisibles, isEmpty);
  });

  test('un conductor no disponible o con el límite agotado no forma parte de C', () {
    final instancia = construir(conductores: [
      conductor(12, disponible: false),
      conductor(8, acumulado: 600, limite: 600),
      conductor(5),
    ]);
    expect(instancia.conductores.keys, [5]);
  });

  test('límite de conducción: C-12 con 540 de 600 min no recibe un servicio de 95 min (HU-03)', () {
    final instancia = construir(conductores: [conductor(12, acumulado: 540, limite: 600)]);
    final resultado = const AlgoritmoGenetico(ParametrosAG(semilla: 1)).resolver(instancia);
    final decodificado = Decodificador(instancia).decodificar(resultado.cromosoma).single;
    expect(decodificado.asignado, isFalse);
    expect(decodificado.motivo, contains('límite de conducción de C-12'));
  });

  test('la alternativa comprometida b(s) pasa a la instancia', () {
    const comprometida = Alternativa(vehiculoId: 2, conductorId: 8, salida: 450, duracion: 95);
    final s = construir(comprometidas: {115: comprometida}).servicios.single;
    expect(s.comprometida, same(comprometida));
    expect(construir(comprometidas: {115: comprometida}).referencias.reprogramacion, 1);
  });

  test('b_Tm = 60 · |V| con los vehículos operativos', () {
    expect(construir().referencias.tiempoMuerto, 120);
  });
}
