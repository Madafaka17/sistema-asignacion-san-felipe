import 'errores.dart';
import '../modelos/tiempo.dart';

/// Lee un objeto JSON exigiendo el tipo exacto de cada campo.
///
/// Los errores se acumulan por campo y [verificar] los lanza juntos como una
/// [ExcepcionApi] de tipo [CodigoError.solicitudInvalida] (HTTP 400). Así un
/// número enviado como texto se rechaza en lugar de convertirse en silencio.
class LectorJson {
  LectorJson(Object? json) : _json = _comoMapa(json);

  final Map<String, Object?> _json;
  final Map<String, String> errores = {};

  static Map<String, Object?> _comoMapa(Object? json) {
    if (json is Map<String, Object?>) return json;
    if (json is Map) return {for (final e in json.entries) e.key.toString(): e.value};
    throw ExcepcionApi(
      CodigoError.solicitudInvalida,
      'El cuerpo de la solicitud debe ser un objeto JSON',
    );
  }

  bool contiene(String campo) => _json.containsKey(campo) && _json[campo] != null;

  String texto(String campo, {int maximo = 255, bool vacioPermitido = false}) {
    final valor = _json[campo];
    if (valor is! String) {
      errores[campo] = valor == null ? 'Campo obligatorio' : 'Debe ser texto';
      return '';
    }
    final recortado = valor.trim();
    if (!vacioPermitido && recortado.isEmpty) {
      errores[campo] = 'Campo obligatorio';
    } else if (recortado.length > maximo) {
      errores[campo] = 'Máximo $maximo caracteres';
    }
    return recortado;
  }

  String? textoOpcional(String campo, {int maximo = 255}) =>
      contiene(campo) ? texto(campo, maximo: maximo, vacioPermitido: true) : null;

  int entero(String campo) {
    final valor = _json[campo];
    if (valor is int) return valor;
    errores[campo] = valor == null ? 'Campo obligatorio' : 'Debe ser un número entero';
    return 0;
  }

  int? enteroOpcional(String campo) => contiene(campo) ? entero(campo) : null;

  double decimal(String campo) {
    final valor = _json[campo];
    if (valor is num) return valor.toDouble();
    errores[campo] = valor == null ? 'Campo obligatorio' : 'Debe ser un número';
    return 0;
  }

  bool booleano(String campo) {
    final valor = _json[campo];
    if (valor is bool) return valor;
    errores[campo] = valor == null ? 'Campo obligatorio' : 'Debe ser verdadero o falso';
    return false;
  }

  /// Fecha en formato `AAAA-MM-DD`.
  DateTime fecha(String campo) {
    final valor = _json[campo];
    if (valor is String) {
      final fecha = intentarTextoAFecha(valor);
      if (fecha != null) return fecha;
    }
    errores[campo] = valor == null ? 'Campo obligatorio' : 'Fecha inválida (AAAA-MM-DD)';
    return DateTime.utc(1970);
  }

  DateTime? fechaOpcional(String campo) => contiene(campo) ? fecha(campo) : null;

  /// Fecha y hora en formato ISO 8601.
  DateTime fechaHora(String campo) {
    final valor = _json[campo];
    final fecha = valor is String ? DateTime.tryParse(valor) : null;
    if (fecha != null) return fecha;
    errores[campo] = valor == null ? 'Campo obligatorio' : 'Fecha y hora inválidas';
    return DateTime.utc(1970);
  }

  DateTime? fechaHoraOpcional(String campo) => contiene(campo) ? fechaHora(campo) : null;

  List<int> listaEnteros(String campo) {
    final valor = _json[campo];
    if (valor is List && valor.every((e) => e is int)) return valor.cast<int>();
    errores[campo] = valor == null ? 'Campo obligatorio' : 'Debe ser una lista de enteros';
    return const [];
  }

  /// Valor de una enumeración a partir de su representación textual.
  T enumeracion<T extends Enum>(String campo, List<T> valores, String Function(T) aTexto) {
    final valor = _json[campo];
    for (final opcion in valores) {
      if (aTexto(opcion) == valor) return opcion;
    }
    errores[campo] = valor == null
        ? 'Campo obligatorio'
        : 'Valor no permitido; opciones: ${valores.map(aTexto).join(', ')}';
    return valores.first;
  }

  Map<String, Object?> objeto(String campo) {
    final valor = _json[campo];
    if (valor is Map) return {for (final e in valor.entries) e.key.toString(): e.value};
    errores[campo] = valor == null ? 'Campo obligatorio' : 'Debe ser un objeto';
    return const {};
  }

  List<Object?> lista(String campo) {
    final valor = _json[campo];
    if (valor is List) return valor;
    errores[campo] = valor == null ? 'Campo obligatorio' : 'Debe ser una lista';
    return const [];
  }

  /// Lanza los errores acumulados, si los hay.
  void verificar() {
    if (errores.isNotEmpty) {
      throw ExcepcionApi(
        CodigoError.solicitudInvalida,
        'La solicitud tiene campos inválidos',
        campos: errores,
      );
    }
  }
}
