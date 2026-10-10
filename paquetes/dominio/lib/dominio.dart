/// Dominio compartido del sistema de asignación de recursos de Transportes y
/// Turismo San Felipe S.A.C.
///
/// * `contrato/`: versión de la API, errores, lectura estricta de JSON y
///   paginación, comunes al servidor y al cliente.
/// * `modelos/`: entidades del dominio (Tabla 11 de la tesis).
/// * `optimizacion/`: núcleo de optimización aislado (sección 3.1.9): no
///   accede a la base de datos ni a la interfaz.
library;

export 'src/contrato/errores.dart';
export 'src/contrato/lector_json.dart';
export 'src/contrato/pagina.dart';
export 'src/contrato/version.dart';
export 'src/modelos/bitacora.dart';
export 'src/modelos/conductor.dart';
export 'src/modelos/incidencia.dart';
export 'src/modelos/indicadores.dart';
export 'src/modelos/programacion.dart';
export 'src/modelos/ruta.dart';
export 'src/modelos/servicio_programado.dart';
export 'src/modelos/tiempo.dart';
export 'src/modelos/usuario.dart';
export 'src/modelos/vehiculo.dart';
export 'src/optimizacion/algoritmo_genetico.dart';
export 'src/optimizacion/algoritmo_voraz.dart';
export 'src/optimizacion/constructor_instancia.dart';
export 'src/optimizacion/decodificador.dart';
export 'src/optimizacion/estrategia.dart';
export 'src/optimizacion/evaluador.dart';
export 'src/optimizacion/fabrica_estrategias.dart';
export 'src/optimizacion/generador_instancias.dart';
export 'src/optimizacion/instancia.dart';
export 'src/optimizacion/parametros.dart';
export 'src/optimizacion/reparacion.dart';
export 'src/optimizacion/validador.dart';
