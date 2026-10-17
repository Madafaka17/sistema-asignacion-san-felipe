/// Página de resultados de un listado (`?pagina=1&tamano=50`).
///
/// Evita serializar y transmitir todos los registros de una tabla en cada
/// consulta.
class Pagina<T> {
  const Pagina({
    required this.elementos,
    required this.total,
    required this.pagina,
    required this.tamano,
  });

  final List<T> elementos;
  final int total;
  final int pagina;
  final int tamano;

  int get totalPaginas => tamano == 0 ? 0 : (total + tamano - 1) ~/ tamano;

  Map<String, Object?> toJson(Map<String, Object?> Function(T) elementoAJson) => {
        'elementos': [for (final e in elementos) elementoAJson(e)],
        'total': total,
        'pagina': pagina,
        'tamano': tamano,
      };

  factory Pagina.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, Object?>) elementoDesdeJson,
  ) =>
      Pagina(
        elementos: [
          for (final e in json['elementos'] as List)
            elementoDesdeJson((e as Map).cast<String, Object?>()),
        ],
        total: json['total'] as int,
        pagina: json['pagina'] as int,
        tamano: json['tamano'] as int,
      );
}

/// Parámetros de paginación validados.
class ParametrosPagina {
  ParametrosPagina({int pagina = 1, int tamano = 50})
      : pagina = pagina < 1 ? 1 : pagina,
        tamano = tamano.clamp(1, tamanoMaximo);

  static const tamanoMaximo = 200;

  final int pagina;
  final int tamano;

  int get desplazamiento => (pagina - 1) * tamano;

  factory ParametrosPagina.desdeConsulta(Map<String, String> consulta) =>
      ParametrosPagina(
        pagina: int.tryParse(consulta['pagina'] ?? '') ?? 1,
        tamano: int.tryParse(consulta['tamano'] ?? '') ?? 50,
      );
}
