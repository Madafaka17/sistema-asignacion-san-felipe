import 'package:dominio/dominio.dart';

/// Formatos de presentación (es-PE).
String fechaCorta(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

String fechaHora(DateTime f) => '${fechaCorta(f)} ${minutosAHora(f.hour * 60 + f.minute)}';

String porcentaje(double valor) => '${Indicadores.redondear(valor).toStringAsFixed(1)} %';

String hora(int? minutos) => minutos == null ? '—' : minutosAHora(minutos);
