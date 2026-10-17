import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

/// Procedencia de una propuesta (sección 5.5 y Tabla 48 de la tesis): el
/// snapshot de la entrada tiene una huella estable y basta, con la semilla,
/// los parámetros y la versión del núcleo, para repetir la ejecución.
void main() {
  final fecha = DateTime.utc(2026, 11, 12);

  DatosTurno datos({bool invertido = false}) {
    List<T> orden<T>(List<T> l) => invertido ? l.reversed.toList() : l;
    final vehiculos = [
      for (final id in [1, 2, 3])
        Vehiculo(id: id, codigo: 'V-0$id', placa: 'AHK-10$id', capacidad: 16, categoria: CategoriaVehiculo.m2),
    ];
    final conductores = [
      for (final id in [11, 12, 13])
        Conductor(
          id: id,
          codigo: 'C-$id',
          dni: '700000$id',
          nombres: 'Conductor',
          apellidos: 'Prueba $id',
          categoriaLicencia: CategoriaLicencia.aIIb,
          vencimientoLicencia: DateTime.utc(2027, 6, 30),
          turnoInicio: 300,
          turnoFin: 1140,
          limiteMinutos: 600,
        ),
    ];
    return DatosTurno(
      fecha: fecha,
      servicios: orden([
        for (final (i, h) in [360, 390, 420, 450].indexed)
          ServicioProgramado(
            id: i + 1,
            codigo: 'S-00${i + 1}',
            fecha: fecha,
            rutaId: 1,
            horaSolicitada: h,
            prioridad: 3 - i % 3,
            capacidadRequerida: 10,
            entradaColaId: i < 3 ? i + 1 : null,
          ),
      ]),
      vehiculos: orden(vehiculos),
      conductores: orden(conductores),
      rutas: const [
        Ruta(
            id: 1,
            codigo: 'R-01',
            origen: 'Soritor',
            destino: 'Moyobamba',
            duracionMin: 90,
            idaMin: 30,
            vehiculosCompatibles: [1, 2, 3]),
      ],
      salidas: orden([for (var h = 360; h <= 540; h += 30) SalidaAutorizada(id: h, rutaId: 1, hora: h)]),
      entradas: orden([
        for (final (i, v) in [1, 2, 3].indexed)
          EntradaCola(id: i + 1, rutaId: 1, fecha: fecha, vehiculoId: v, posicion: i + 1, llegada: 320 + i * 5),
      ]),
      pares: orden([
        for (final v in [1, 2, 3]) ...[
          ParAutorizado(vehiculoId: v, conductorId: 10 + v, tipo: TipoPar.habitual),
          ParAutorizado(vehiculoId: v, conductorId: 13 - v % 2, tipo: TipoPar.reemplazo),
        ],
      ]),
      comprometidas: const {4: Alternativa(vehiculoId: 1, conductorId: 11, salida: 450, duracion: 90)},
    );
  }

  test('el JSON canónico ordena las claves en todos los niveles', () {
    expect(
      jsonCanonico({
        'b': 1,
        'a': {
          'd': 2,
          'c': [
            {'z': 1, 'y': 2},
          ],
        },
      }),
      '{"a":{"c":[{"y":2,"z":1}],"d":2},"b":1}',
    );
  });

  test('la misma entrada tiene la misma huella aunque llegue en otro orden', () {
    expect(jsonCanonico(datos(invertido: true).toJson()), jsonCanonico(datos().toJson()));
  });

  test('el snapshot vuelve a ser la misma entrada', () {
    final original = datos();
    final copia = DatosTurno.fromJson(original.toJson());
    expect(jsonCanonico(copia.toJson()), jsonCanonico(original.toJson()));
    expect(copia.comprometidas[4]!.mismaQue(original.comprometidas[4]), isTrue);
    expect(copia.entradas.first.posicion, 1);
    expect(copia.pares.where((p) => p.tipo == TipoPar.habitual), hasLength(3));
  });

  test('con el snapshot, la semilla y los parámetros la propuesta se repite', () {
    const parametros = ParametrosModelo();
    const ag = AlgoritmoGenetico(ParametrosAG(semilla: 7));
    final primera = ag.resolver(const ConstructorInstancia(parametros).construir(datos()));
    final repetida = ag.resolver(
      const ConstructorInstancia(parametros).construir(DatosTurno.fromJson(datos(invertido: true).toJson())),
    );
    expect(repetida.cromosoma, primera.cromosoma);
    expect(repetida.evaluacion.aptitud, primera.evaluacion.aptitud);
    expect(primera.versionAlgoritmo, 'algoritmo_genetico@$versionNucleo');
  });

  test('la programación lleva su versión, su ejecución y su procedencia', () {
    final p = Programacion(
      id: 9,
      fecha: fecha,
      estado: EstadoProgramacion.sustituida,
      metodo: 'algoritmo_genetico',
      aptitud: -0.2,
      phi: 0,
      phiValidador: 0,
      componentes: const ComponentesAptitud(),
      generaciones: 20,
      tiempoMs: 80,
      creadoPor: 'operaciones',
      creadoEn: DateTime.utc(2026, 11, 11, 10),
      version: 2,
      ejecucionId: 7,
      versionAnteriorId: 7,
      huellaEntrada: 'a' * 64,
      versionAlgoritmo: 'algoritmo_genetico@$versionNucleo',
      tiempoNucleoMs: 35,
    );
    final copia = Programacion.fromJson(p.toJson());
    expect((copia.version, copia.ejecucionId, copia.versionAnteriorId), (2, 7, 7));
    expect((copia.huellaEntrada, copia.tiempoNucleoMs), ('a' * 64, 35));
    expect(copia.estado, EstadoProgramacion.sustituida);
    final primera =
        Programacion.fromJson({...p.toJson(), 'id': 7, 'version': 1, 'ejecucionId': 7, 'versionAnteriorId': null});
    expect(primera.versionAnteriorId, isNull);
  });

  test('una demora también se explica y exige motivo si se introduce a mano', () {
    // S-001 sale a las 06:00, pero C-11 y C-13 solo entran a las 06:30.
    final base = datos();
    final turno = DatosTurno(
      fecha: fecha,
      servicios: [base.servicios.first],
      vehiculos: base.vehiculos,
      conductores: [
        for (final c in base.conductores)
          Conductor(
            id: c.id,
            codigo: c.codigo,
            dni: c.dni,
            nombres: c.nombres,
            apellidos: c.apellidos,
            categoriaLicencia: c.categoriaLicencia,
            vencimientoLicencia: c.vencimientoLicencia,
            turnoInicio: 390,
            turnoFin: c.turnoFin,
            limiteMinutos: c.limiteMinutos,
          ),
      ],
      rutas: base.rutas,
      salidas: base.salidas,
      entradas: base.entradas,
      pares: base.pares,
    );
    final instancia = const ConstructorInstancia(ParametrosModelo()).construir(turno);
    final s = instancia.servicios.single;
    final a = s.alternativas.firstWhere((a) => a.vehiculoId == 1 && a.conductorId == 11);
    final x = ExcepcionesAsignacion.de(instancia, s, a);
    expect(x.demoraMin, 30);
    expect(x.requiereJustificacion, isTrue);
    expect(x.explicacion, contains('demora de 30 min: ninguna alternativa admisible sale a la hora nominal'));
  });
}
