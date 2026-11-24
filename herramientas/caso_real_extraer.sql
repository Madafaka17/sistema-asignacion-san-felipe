-- Extracción del caso real (herramientas/caso_real.sh): entrada, salida y bitácora.
SELECT '== Entrada del caso (registrada por despacho en la interfaz)' AS ``;
SELECT codigo, placa, capacidad, categoria, estado, creado_en FROM vehiculo;
SELECT codigo, dni, CONCAT(nombres, ' ', apellidos) AS nombre, categoria_licencia, vencimiento_licencia, turno_inicio, turno_fin, minutos_acumulados, limite_minutos, creado_en FROM conductor;
SELECT v.codigo AS vehiculo, c.codigo AS conductor, p.tipo FROM par_autorizado p JOIN vehiculo v ON v.id = p.vehiculo_id JOIN conductor c ON c.id = p.conductor_id;
SELECT codigo, origen, destino, duracion_min, ida_min FROM ruta;
SELECT r.codigo AS ruta, s.hora AS salida_min FROM salida_autorizada s JOIN ruta r ON r.id = s.ruta_id;
SELECT c.fecha, r.codigo AS ruta, v.codigo AS vehiculo, e.posicion, e.llegada AS llegada_min, e.creado_en FROM entrada_cola e JOIN cola c ON c.id = e.cola_id JOIN ruta r ON r.id = c.ruta_id JOIN vehiculo v ON v.id = e.vehiculo_id;
SELECT s.codigo, s.fecha, r.codigo AS ruta, s.hora_solicitada, s.prioridad, s.capacidad_requerida, s.estado, u.nombre_usuario AS creado_por, s.creado_en FROM servicio s JOIN ruta r ON r.id = s.ruta_id JOIN usuario u ON u.id = s.creado_por;
SELECT '== Entrada congelada del núcleo (snapshot)' AS ``;
SELECT id, fecha, sha256, creado_en, contenido FROM snapshot_entrada;
SELECT '== Salida del sistema (programación y asignación)' AS ``;
SELECT id, fecha, estado, version, metodo, version_algoritmo, aptitud, phi, phi_validador, conflictos_vehiculo, conflictos_conductor, conductores_excedidos, perdida, generaciones, tiempo_ms, semilla, creado_en, aprobado_en FROM programacion;
SELECT s.codigo AS servicio, v.codigo AS vehiculo, c.codigo AS conductor, a.salida AS salida_min, a.fin AS fin_min, a.estado, a.salto_cola, a.reemplazo, a.demora_min FROM asignacion a JOIN servicio s ON s.id = a.servicio_id LEFT JOIN vehiculo v ON v.id = a.vehiculo_id LEFT JOIN conductor c ON c.id = a.conductor_id;
SELECT '== Bitácora (hora de Lima, UTC-5)' AS ``;
SELECT b.fecha_hora, u.nombre_usuario, b.accion, b.entidad, b.entidad_id, b.detalle FROM bitacora b LEFT JOIN usuario u ON u.id = b.usuario_id ORDER BY b.id;
