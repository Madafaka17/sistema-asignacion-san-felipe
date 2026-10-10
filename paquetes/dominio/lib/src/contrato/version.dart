/// Versión del contrato REST que comparten el servidor y el cliente.
///
/// Sigue el esquema MAYOR.MENOR.PARCHE de las etiquetas de lanzamiento del
/// repositorio (`v1.0.0`). Un cliente `vX.Y.*` solo opera con un servidor
/// `vX.Y.*`: un cambio de MAYOR o MENOR cambia la forma de los datos.
const String versionApi = '1.0.0';

/// Indica si dos versiones del contrato pueden operar juntas: deben coincidir
/// en MAYOR y MENOR. Devuelve `false` si alguna versión está mal formada.
bool versionesCompatibles(String a, String b) {
  final partesA = _partes(a);
  final partesB = _partes(b);
  if (partesA == null || partesB == null) return false;
  return partesA[0] == partesB[0] && partesA[1] == partesB[1];
}

List<int>? _partes(String version) {
  final coincidencia = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(version);
  if (coincidencia == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(coincidencia.group(i)!)];
}

/// Respuesta de `GET /api/version`.
class InfoVersion {
  const InfoVersion({required this.versionApi, required this.versionServidor});

  final String versionApi;
  final String versionServidor;

  Map<String, Object?> toJson() =>
      {'versionApi': versionApi, 'versionServidor': versionServidor};

  factory InfoVersion.fromJson(Map<String, Object?> json) => InfoVersion(
        versionApi: json['versionApi'] as String,
        versionServidor: json['versionServidor'] as String,
      );
}
