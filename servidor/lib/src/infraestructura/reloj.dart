/// Fuente de la fecha y hora actuales. Se inyecta en los servicios para que
/// las reglas que dependen del día (vigencia de licencias, bloqueo de
/// cuentas) puedan probarse con una fecha fija.
abstract interface class Reloj {
  /// Fecha y hora locales de la empresa, representadas como `DateTime` UTC.
  DateTime ahora();
}

/// Hora local de la empresa con un desfase fijo respecto de UTC (Perú no
/// usa horario de verano).
class RelojSistema implements Reloj {
  const RelojSistema({this.desfaseMinutos = -300});

  final int desfaseMinutos;

  @override
  DateTime ahora() => DateTime.now().toUtc().add(Duration(minutes: desfaseMinutos));
}

/// Reloj controlable para pruebas.
class RelojFijo implements Reloj {
  RelojFijo(this.momento);

  DateTime momento;

  @override
  DateTime ahora() => momento;

  void avanzar(Duration duracion) => momento = momento.add(duracion);
}
