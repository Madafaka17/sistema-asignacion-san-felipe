import 'dart:convert';

/// JSON canónico: las claves de cada objeto ordenadas, sin espacios.
///
/// Dos representaciones con el mismo contenido producen el mismo texto, de
/// modo que su huella SHA-256 identifica el contenido y no el orden en que
/// se armó (procedencia de la entrada, sección 5.5 de la tesis).
String jsonCanonico(Object? valor) => jsonEncode(_ordenar(valor));

Object? _ordenar(Object? valor) => switch (valor) {
      Map() => {
          for (final e in valor.entries.toList()..sort((a, b) => '${a.key}'.compareTo('${b.key}')))
            '${e.key}': _ordenar(e.value),
        },
      List() => [for (final e in valor) _ordenar(e)],
      _ => valor,
    };
