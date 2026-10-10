import 'package:dominio/dominio.dart';
import 'package:test/test.dart';

void main() {
  group('Versión del contrato', () {
    test('cliente y servidor son compatibles si coinciden MAYOR y MENOR', () {
      expect(versionesCompatibles('1.2.0', '1.2.7'), isTrue);
      expect(versionesCompatibles('v1.2.0', '1.2.0'), isTrue);
      expect(versionesCompatibles('1.2.0', '1.3.0'), isFalse);
      expect(versionesCompatibles('1.2.0', '2.2.0'), isFalse);
      expect(versionesCompatibles('1.2', '1.2.0'), isFalse);
    });
  });

  group('Lectura estricta de JSON', () {
    test('un número enviado como texto se rechaza con HTTP 400', () {
      expect(
        () => Vehiculo.fromJson({
          'codigo': 'V-07',
          'placa': 'ABC-123',
          'capacidad': '15',
          'categoria': 'M2',
          'estado': 'operativo',
        }),
        throwsA(isA<ExcepcionApi>()
            .having((e) => e.estadoHttp, 'estadoHttp', 400)
            .having((e) => e.campos['capacidad'], 'campo', 'Debe ser un número entero')),
      );
    });

    test('acumula los errores de todos los campos', () {
      try {
        ServicioProgramado.fromJson({'codigo': 'S-115'});
        fail('Debió lanzar una excepción');
      } on ExcepcionApi catch (e) {
        expect(e.campos.keys, containsAll(['fecha', 'rutaId', 'horaSolicitada', 'prioridad']));
      }
    });

    test('una enumeración desconocida indica las opciones', () {
      expect(
        () => Vehiculo.fromJson({
          'codigo': 'V-07',
          'placa': 'ABC-123',
          'capacidad': 15,
          'categoria': 'M9',
          'estado': 'operativo',
        }),
        throwsA(isA<ExcepcionApi>().having((e) => e.campos['categoria'], 'campo', contains('M1'))),
      );
    });

    test('ida y vuelta de un servicio por JSON', () {
      final servicio = ServicioProgramado(
        id: 9,
        codigo: 's-115',
        fecha: DateTime.utc(2026, 11, 12),
        rutaId: 3,
        horaSolicitada: 450,
        prioridad: 3,
        capacidadRequerida: 12,
      );
      final copia = ServicioProgramado.fromJson(servicio.toJson());
      expect(copia.codigo, 'S-115');
      expect(copia.fecha, DateTime.utc(2026, 11, 12));
      expect(copia.toJson(), {...servicio.toJson(), 'codigo': 'S-115'});
    });

    test('el error de la API se reconstruye a partir de su JSON', () {
      final original = ExcepcionApi(CodigoError.conflicto, 'La placa ya está registrada', campos: {'placa': 'Duplicada'});
      final copia = ExcepcionApi.fromJson(original.toJson());
      expect(copia.codigo, CodigoError.conflicto);
      expect(copia.mensaje, 'La placa ya está registrada');
      expect(copia.campos, {'placa': 'Duplicada'});
    });
  });

  group('Tiempo', () {
    test('minutos y horas', () {
      expect(minutosAHora(450), '07:30');
      expect(horaAMinutos('07:30'), 450);
      expect(horaAMinutos('24:00'), isNull);
    });

    test('fechas', () {
      expect(fechaATexto(DateTime.utc(2026, 1, 5)), '2026-01-05');
      expect(intentarTextoAFecha('2026-02-30'), isNull);
    });
  });

  group('Permisos por rol (HU-01)', () {
    test('despacho ve solo registros e incidencias', () {
      final modulos = Permisos.modulosNavegacion(Rol.despacho);
      expect(modulos, isNot(contains(Modulo.programacion)));
      expect(modulos, isNot(contains(Modulo.reportes)));
      expect(modulos, isNot(contains(Modulo.usuarios)));
      expect(modulos, containsAll([Modulo.vehiculos, Modulo.servicios, Modulo.incidencias]));
    });

    test('solo operaciones aprueba programaciones y solo el administrador gestiona usuarios', () {
      expect(Permisos.puedeEscribir(Rol.operaciones, Modulo.programacion), isTrue);
      expect(Permisos.puedeEscribir(Rol.despacho, Modulo.programacion), isFalse);
      expect(Permisos.puedeEscribir(Rol.administrador, Modulo.usuarios), isTrue);
      expect(Permisos.puedeLeer(Rol.operaciones, Modulo.usuarios), isFalse);
    });
  });

  group('Indicadores (ecuaciones 19 a 23)', () {
    test('noviembre de 2026: 190 servicios, 12 reprogramados y 9 con retraso (HU-11)', () {
      expect(Indicadores.redondear(Indicadores.psr(12, 190)), 6.3);
      expect(Indicadores.redondear(Indicadores.psa(9, 190)), 4.7);
    });

    test('PIO suma las asignaciones inadecuadas de vehículos y conductores', () {
      expect(Indicadores.pio(179, 196, 2310), closeTo(16.23, 0.01));
    });

    test('un denominador cero da 0', () {
      expect(Indicadores.puv(0, 0), 0);
      expect(Indicadores.pav(0, 0), 0);
    });
  });
}
