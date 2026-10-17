/// Conversión entre la representación del modelo y la de presentación.
///
/// En el modelo de la tesis las horas son minutos desde la medianoche,
/// `t ∈ [0, 1440)`, y así se guardan en la base de datos. Las fechas son
/// días calendario sin zona horaria (`DateTime` UTC a las 00:00).
library;

const minutosPorDia = 1440;

/// `450` → `"07:30"`.
String minutosAHora(int minutos) {
  final h = (minutos ~/ 60).toString().padLeft(2, '0');
  final m = (minutos % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// `"07:30"` → `450`; `null` si el texto no es una hora válida.
int? horaAMinutos(String texto) {
  final coincidencia = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(texto.trim());
  if (coincidencia == null) return null;
  final h = int.parse(coincidencia.group(1)!);
  final m = int.parse(coincidencia.group(2)!);
  if (h > 23 || m > 59) return null;
  return h * 60 + m;
}

bool esMinutoDelDia(int minutos) => minutos >= 0 && minutos < minutosPorDia;

/// `DateTime` → `"2026-11-12"`.
String fechaATexto(DateTime fecha) {
  final a = fecha.year.toString().padLeft(4, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  final d = fecha.day.toString().padLeft(2, '0');
  return '$a-$m-$d';
}

/// `"2026-11-12"` → `DateTime.utc(2026, 11, 12)`; `null` si no es válida.
DateTime? intentarTextoAFecha(String texto) {
  final coincidencia = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(texto.trim());
  if (coincidencia == null) return null;
  final a = int.parse(coincidencia.group(1)!);
  final m = int.parse(coincidencia.group(2)!);
  final d = int.parse(coincidencia.group(3)!);
  final fecha = DateTime.utc(a, m, d);
  if (fecha.year != a || fecha.month != m || fecha.day != d) return null;
  return fecha;
}

DateTime textoAFecha(String texto) =>
    intentarTextoAFecha(texto) ?? (throw FormatException('Fecha inválida: $texto'));

/// Solo el día calendario de [momento], sin la hora.
DateTime soloFecha(DateTime momento) => DateTime.utc(momento.year, momento.month, momento.day);

/// `"12/11/2026"`, como se muestra al usuario.
String fechaAPresentacion(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
