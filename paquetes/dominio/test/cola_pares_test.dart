import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

/// Reglas de cola y de conductores de la sección 3.1.2: la ecuación (1) exige
/// además `v ∈ {v0(s), v1(s)}` y `c ∈ {chab(v)} ∪ C_v^R`; las salidas
/// `σ(s)`, `η(s)` y `Δt(s)` registran las excepciones.
void main() {
  final fecha = DateTime.utc(2026, 11, 12);

  Vehiculo vehiculo(int id, {int capacidad = 16, EstadoVehiculo estado = EstadoVehiculo.operativo}) => Vehiculo(
        id: id,
        codigo: 'V-0$id',
        placa: 'ABC-10$id',
        capacidad: capacidad,
        categoria: CategoriaVehiculo.m2,
        estado: estado,
      );

  Conductor conductor(int id, {bool disponible = true, CategoriaLicencia licencia = CategoriaLicencia.aIIb}) =>
      Conductor(
        id: id,
        codigo: 'C-$id',
        dni: '700000${id.toString().padLeft(2, '0')}',
        nombres: 'Nombre$id',
        apellidos: 'Apellido$id',
        categoriaLicencia: licencia,
        vencimientoLicencia: DateTime.utc(2027, 6, 30),
        turnoInicio: 300,
        turnoFin: 1140,
        limiteMinutos: 600,
        disponible: disponible,
      );

  // R-01 Soritor–Moyobamba: ida declarada de 30 min y ciclo de 90 min.
  const ruta = Ruta(
    id: 1,
    codigo: 'R-01',
    origen: 'Soritor',
    destino: 'Moyobamba',
    duracionMin: 90,
    idaMin: 30,
    vehiculosCompatibles: [1, 2, 3, 4],
  );
  final salidas = [
    for (final h in [360, 390, 420]) SalidaAutorizada(id: h, rutaId: 1, hora: h),
  ];

  EntradaCola entrada(int id, int vehiculoId, int posicion, {bool activa = true}) => EntradaCola(
        id: id,
        rutaId: 1,
        fecha: fecha,
        vehiculoId: vehiculoId,
        posicion: posicion,
        llegada: 300 + posicion * 5,
        activa: activa,
      );

  ServicioProgramado servicio({int? entradaColaId, int capacidad = 10, int hora = 360}) => ServicioProgramado(
        id: 115,
        codigo: 'S-115',
        fecha: fecha,
        rutaId: 1,
        horaSolicitada: hora,
        prioridad: 2,
        capacidadRequerida: capacidad,
        entradaColaId: entradaColaId,
      );

  // Cada unidad tiene un conductor habitual (C-1x) y un reemplazo común (C-20).
  final paresBase = [
    for (final v in [1, 2, 3, 4]) ...[
      ParAutorizado(vehiculoId: v, conductorId: 10 + v, tipo: TipoPar.habitual),
      ParAutorizado(vehiculoId: v, conductorId: 20, tipo: TipoPar.reemplazo),
    ],
  ];

  InstanciaTurno construir({
    ServicioProgramado? s,
    List<Vehiculo>? vehiculos,
    List<Conductor>? conductores,
    List<EntradaCola>? entradas,
    List<ParAutorizado>? pares,
    ParametrosModelo parametros = const ParametrosModelo(toleranciaSalidaMin: 30),
  }) =>
      ConstructorInstancia(parametros).construir(
        DatosTurno(
          fecha: fecha,
          servicios: [s ?? servicio(entradaColaId: 1)],
          vehiculos: vehiculos ?? [vehiculo(1), vehiculo(2), vehiculo(3), vehiculo(4)],
          conductores:
              conductores ?? [conductor(11), conductor(12), conductor(13), conductor(14), conductor(20), conductor(30)],
          rutas: [ruta],
          salidas: salidas,
          entradas: entradas ?? [entrada(1, 1, 1), entrada(2, 2, 2), entrada(3, 3, 3)],
          pares: pares ?? paresBase,
        ),
      );

  Set<int> unidades(ServicioTurno s) => {for (final a in s.alternativas) a.vehiculoId};
  Set<int> conductoresDe(ServicioTurno s, int vehiculoId) => {
        for (final a in s.alternativas)
          if (a.vehiculoId == vehiculoId) a.conductorId,
      };

  group('v ∈ {v0(s), v1(s)}: unidad que corresponde y siguiente elegible de la cola', () {
    test('solo entran la unidad en turno y la siguiente de la cola', () {
      final s = construir().servicios.single;
      expect(s.vehiculoCola, 1);
      expect(s.posicionCola, 1);
      expect(s.vehiculoSiguiente, 2);
      expect(unidades(s), {1, 2});
      expect(s.nominal, 360);
    });

    test('un servicio sin turno en la cola no está sujeto a la regla', () {
      final s = construir(s: servicio()).servicios.single;
      expect(s.vehiculoCola, isNull);
      expect(unidades(s), {1, 2, 3, 4});
    });

    test('si la unidad en turno está en mantenimiento solo queda la siguiente (σ forzado)', () {
      final instancia = construir(
        vehiculos: [
          vehiculo(1, estado: EstadoVehiculo.mantenimiento),
          vehiculo(2),
          vehiculo(3),
          vehiculo(4),
        ],
      );
      final s = instancia.servicios.single;
      expect(unidades(s), {2});
      final x = ExcepcionesAsignacion.de(instancia, s, s.alternativas.first);
      expect(x.saltoCola, isTrue);
      expect(x.explicacion, contains('la unidad que corresponde (V-01) no está disponible'));
    });

    test('la siguiente elegible salta las entradas de la misma unidad, inactivas o sin capacidad', () {
      final s = construir(
        vehiculos: [vehiculo(1), vehiculo(2, capacidad: 8), vehiculo(3), vehiculo(4)],
        entradas: [
          entrada(1, 1, 1),
          entrada(2, 1, 2),
          entrada(3, 2, 3),
          entrada(4, 3, 4, activa: false),
          entrada(5, 4, 5),
        ],
      ).servicios.single;
      expect(s.vehiculoSiguiente, 4);
      expect(unidades(s), {1, 4});
    });

    test('una unidad que dejó la cola ya no es alternativa; todas sus alternativas son salto', () {
      final instancia = construir(entradas: [entrada(1, 1, 1, activa: false), entrada(2, 2, 2)]);
      final s = instancia.servicios.single;
      expect(unidades(s), {2});
      expect(s.alternativas.every((a) => ExcepcionesAsignacion.de(instancia, s, a).saltoCola), isTrue);
    });

    test('sin la regla de la siguiente unidad, v ∈ {v0(s)}', () {
      final s = construir(parametros: const ParametrosModelo(toleranciaSalidaMin: 30, permitirSiguienteUnidad: false))
          .servicios
          .single;
      expect(s.vehiculoSiguiente, isNull);
      expect(unidades(s), {1});
    });

    test('sin unidad elegible el servicio queda sin alternativas y se explica', () {
      final s = construir(entradas: [entrada(1, 1, 1, activa: false)]).servicios.single;
      expect(s.tieneAlternativas, isFalse);
      expect(
        s.motivoSinAlternativas,
        'La unidad que corresponde en la cola (V-01, posición 1) dejó la cola y no hay otra unidad '
        'elegible después de ella en la cola de R-01',
      );
    });
  });

  group('c ∈ {chab(v)} ∪ C_v^R: conductor habitual o reemplazo autorizado', () {
    test('cada unidad solo admite a su habitual y a sus reemplazos', () {
      final instancia = construir();
      final s = instancia.servicios.single;
      expect(conductoresDe(s, 1), {11, 20});
      expect(conductoresDe(s, 2), {12, 20});
      expect(instancia.habituales, {1: 11, 2: 12, 3: 13, 4: 14});
    });

    test('sin exigir pares cualquier conductor habilitado es admisible', () {
      final s = construir(parametros: const ParametrosModelo(toleranciaSalidaMin: 30, exigirParAutorizado: false))
          .servicios
          .single;
      expect(conductoresDe(s, 1), {11, 12, 13, 14, 20, 30});
    });

    test('una unidad sin pares registrados no tiene conductores', () {
      final s = construir(pares: const [], entradas: [entrada(1, 1, 1)]).servicios.single;
      expect(s.tieneAlternativas, isFalse);
      expect(
        s.motivoSinAlternativas,
        'La unidad V-01 no tiene conductor habitual ni reemplazos autorizados registrados',
      );
    });

    test('si los conductores autorizados no están disponibles se explica', () {
      final s = construir(
        entradas: [entrada(1, 1, 1)],
        conductores: [
          conductor(11, disponible: false),
          conductor(20, licencia: CategoriaLicencia.aIIa),
          conductor(30),
        ],
      ).servicios.single;
      expect(s.tieneAlternativas, isFalse);
      expect(s.motivoSinAlternativas, startsWith('Ningún conductor autorizado de V-01'));
    });
  });

  group('Salidas σ(s), η(s) y Δt(s) (Tabla 11)', () {
    test('la alternativa preferente no es excepción', () {
      final instancia = construir();
      final s = instancia.servicios.single;
      final preferente = s.alternativas.firstWhere((a) => a.vehiculoId == 1 && a.conductorId == 11 && a.salida == 360);
      final x = ExcepcionesAsignacion.de(instancia, s, preferente);
      expect((x.saltoCola, x.reemplazo, x.demoraMin, x.explicacion), (false, false, 0, null));
      expect(x.requiereJustificacion, isFalse);
    });

    test('siguiente unidad con reemplazo y 30 min de demora', () {
      final instancia = construir();
      final s = instancia.servicios.single;
      final a = s.alternativas.firstWhere((a) => a.vehiculoId == 2 && a.conductorId == 20 && a.salida == 390);
      final x = ExcepcionesAsignacion.de(instancia, s, a);
      expect(x.saltoCola, isTrue);
      expect(x.reemplazo, isTrue);
      expect(x.demoraMin, 30);
      expect(x.vehiculoCola, 1);
      expect(x.conductorHabitual, 12);
      expect(x.requiereJustificacion, isTrue);
      expect(x.explicacion, contains('la unidad que corresponde (V-01) es admisible'));
      expect(x.explicacion, contains('el conductor habitual (C-12) es admisible'));
    });

    test('el reemplazo se explica cuando el habitual no es admisible', () {
      final instancia = construir(conductores: [conductor(11, disponible: false), conductor(12), conductor(20)]);
      final s = instancia.servicios.single;
      final a = s.alternativas.firstWhere((a) => a.vehiculoId == 1);
      final x = ExcepcionesAsignacion.de(instancia, s, a);
      expect(x.reemplazo, isTrue);
      expect(x.explicacion, contains('el conductor habitual (C-11) no está disponible'));
    });

    test('una unidad sin conductor habitual no cuenta reemplazos', () {
      final instancia = construir(
        pares: [
          for (final v in [1, 2]) ParAutorizado(vehiculoId: v, conductorId: 20, tipo: TipoPar.reemplazo),
        ],
      );
      final s = instancia.servicios.single;
      expect(s.alternativas.any((a) => ExcepcionesAsignacion.de(instancia, s, a).reemplazo), isFalse);
    });
  });

  group('Contrato de la cola y de los pares', () {
    test('ida y vuelta de una entrada de cola y de su solicitud', () {
      final e = EntradaCola(
        id: 4,
        rutaId: 1,
        fecha: fecha,
        vehiculoId: 2,
        posicion: 3,
        llegada: 345,
        codigoVehiculo: 'V-02',
        servicioId: 115,
        codigoServicio: 'S-115',
      );
      expect(EntradaCola.fromJson(e.toJson()).toJson(), e.toJson());
      expect(e.libre, isFalse);
      final solicitud = SolicitudEntradaCola(rutaId: 1, fecha: fecha, vehiculoId: 2, llegada: 345);
      expect(SolicitudEntradaCola.fromJson(solicitud.toJson()).toJson(), solicitud.toJson());
    });

    test('los pares se agrupan por unidad', () {
      final grupos = ConductoresAutorizados.porVehiculo([
        const ParAutorizado(vehiculoId: 1, conductorId: 11, tipo: TipoPar.habitual),
        const ParAutorizado(vehiculoId: 1, conductorId: 30, tipo: TipoPar.reemplazo),
        const ParAutorizado(vehiculoId: 1, conductorId: 20, tipo: TipoPar.reemplazo),
        const ParAutorizado(vehiculoId: 2, conductorId: 20, tipo: TipoPar.reemplazo),
      ]);
      expect(grupos[1]!.conductorHabitualId, 11);
      expect(grupos[1]!.reemplazos, [20, 30]);
      expect(grupos[1]!.todos, {11, 20, 30});
      expect(grupos[2]!.conductorHabitualId, isNull);
      final copia = ConductoresAutorizados.fromJson(grupos[1]!.toJson());
      expect(copia.pares.map((p) => p.toJson()), grupos[1]!.pares.map((p) => p.toJson()));
      expect(ParAutorizado.fromJson(copia.pares.first.toJson()).tipo, TipoPar.habitual);
    });

    test('el servicio lleva su turno en la cola y la ruta su ida declarada', () {
      final s = servicio(entradaColaId: 7);
      expect(s.toJsonSolicitud()['entradaColaId'], 7);
      expect(ServicioProgramado.fromJson(s.toJson()).entradaColaId, 7);
      expect(Ruta.fromJson(ruta.toJson()).idaMin, 30);
    });

    test('el ajuste vacío no lleva justificación', () {
      final ajuste = AjusteAsignacion.fromJson({
        'vehiculoId': 1,
        'conductorId': 2,
        'salida': 360,
        'justificacion': '  ',
      });
      expect(ajuste.justificacion, isNull);
      expect(
        AjusteAsignacion.fromJson(
          const AjusteAsignacion(
            vehiculoId: 1,
            conductorId: 2,
            salida: 360,
            justificacion: 'Habitual enfermo',
          ).toJson(),
        ).justificacion,
        'Habitual enfermo',
      );
    });

    test('la programación totaliza Σσ, Ση, las salidas demoradas y ΣΔt', () {
      Asignacion a(String codigo, {bool salto = false, bool reemplazo = false, int demora = 0, bool recursos = true}) =>
          Asignacion(
            servicioId: codigo.hashCode,
            codigoServicio: codigo,
            codigoRuta: 'R-01',
            prioridad: 2,
            vehiculoId: recursos ? 1 : null,
            conductorId: recursos ? 1 : null,
            salida: recursos ? 360 : null,
            fin: recursos ? 450 : null,
            estado: recursos ? EstadoAsignacion.asignado : EstadoAsignacion.incidencia,
            saltoCola: salto,
            reemplazo: reemplazo,
            demoraMin: demora,
          );
      final p = Programacion(
        id: 1,
        fecha: fecha,
        estado: EstadoProgramacion.propuesta,
        metodo: 'algoritmo_genetico',
        aptitud: -0.1,
        phi: 0,
        phiValidador: 0,
        componentes: const ComponentesAptitud(),
        generaciones: 1,
        tiempoMs: 1,
        creadoPor: 'operaciones',
        creadoEn: fecha,
        asignaciones: [
          a('S-1', salto: true, demora: 30),
          a('S-2', reemplazo: true),
          a('S-3', salto: true, reemplazo: true, demora: 10),
          a('S-4', recursos: false),
        ],
      );
      expect((p.saltosCola, p.reemplazos, p.salidasDemoradas, p.minutosDemora), (2, 2, 2, 40));
      final copia = Programacion.fromJson(p.toJson());
      expect(copia.asignaciones.first.saltoCola, isTrue);
      expect(copia.minutosDemora, 40);
    });
  });
}
