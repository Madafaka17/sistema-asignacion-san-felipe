-- Conjunto mínimo controlado para la prueba de humo.
-- DATOS SINTÉTICOS: no son registros de la Empresa de Transportes y Turismo San Felipe S.A.C.
-- Generado por pruebas/humo/generar_semilla.py con el generador registrado
-- experimentos/sintetico_sanfelipe/generador_sanfelipe.py, sin modificarlo:
-- n = 7 servicios, semilla 9001 (el experimento usa las semillas 101, 102, 103).
-- 7 servicios = 6.25 % del turno de referencia de 112 servicios.
-- US.. son unidades y CS.. conductores ficticios; no hay datos personales.

INSERT INTO turno (id_turno, origen_datos, semilla_generador, duracion_min, t_min, b_retraso, b_reprogramacion, b_tiempo_muerto, b_desequilibrio) VALUES
  (1, 'sintetico', 9001, 600.00, 10.00, 60.00, 5.00, 180.00, 60.00);

INSERT INTO ruta (id_ruta, nombre, ida_min) VALUES
  ('MOY', 'Soritor–Moyobamba', 30.00),
  ('TAR', 'Soritor–Tarapoto', 150.00);

INSERT INTO conductor (id_conductor, id_turno, conduccion_previa_min, limite_conduccion_min) VALUES
  ('CS01', 1, 0.00, 615.00),
  ('CS02', 1, 0.00, 627.00),
  ('CS03', 1, 0.00, 377.00),
  ('CS04', 1, 0.00, 90.00);

INSERT INTO unidad (id_unidad, id_turno, asientos, conductor_habitual) VALUES
  ('US01', 1, 16, 'CS01'),
  ('US02', 1, 16, 'CS02'),
  ('US03', 1, 16, 'CS03');

INSERT INTO autorizacion (id_unidad, id_conductor, tipo) VALUES
  ('US01', 'CS01', 'habitual'),
  ('US01', 'CS04', 'reemplazo'),
  ('US02', 'CS02', 'habitual'),
  ('US02', 'CS04', 'reemplazo'),
  ('US03', 'CS02', 'reemplazo'),
  ('US03', 'CS03', 'habitual');

INSERT INTO servicio (id_servicio, id_turno, orden, id_ruta, unidad_en_cola, salida_nominal_min, prioridad, alternativa_comprometida) VALUES
  ('S001', 1, 0, 'TAR', 'US01', 2.00, 2, 0),
  ('S002', 1, 1, 'MOY', 'US02', 18.00, 3, 3),
  ('S003', 1, 2, 'TAR', 'US03', 56.00, 3, 1),
  ('S004', 1, 3, 'MOY', 'US02', 126.00, 2, 1),
  ('S005', 1, 4, 'TAR', 'US02', 242.00, 1, 1),
  ('S006', 1, 5, 'MOY', 'US01', 352.00, 3, NULL),
  ('S007', 1, 6, 'MOY', 'US01', 459.00, 3, NULL);

INSERT INTO alternativa (id_servicio, indice, id_unidad, id_conductor, codigo_salida, inicio_min, duracion_min) VALUES
  ('S001', 0, 'US01', 'CS01', 'h0', 2.00, 322.00),
  ('S001', 1, 'US03', 'CS03', 'h1', 12.00, 322.00),
  ('S002', 0, 'US03', 'CS02', 'h0', 18.00, 96.00),
  ('S002', 1, 'US02', 'CS02', 'h1', 18.00, 96.00),
  ('S002', 2, 'US03', 'CS03', 'h2', 18.00, 96.00),
  ('S002', 3, 'US02', 'CS02', 'h3', 28.00, 96.00),
  ('S003', 0, 'US03', 'CS03', 'h0', 76.00, 327.00),
  ('S003', 1, 'US03', 'CS03', 'h1', 66.00, 327.00),
  ('S003', 2, 'US03', 'CS02', 'h2', 66.00, 327.00),
  ('S003', 3, 'US03', 'CS02', 'h3', 76.00, 327.00),
  ('S003', 4, 'US03', 'CS03', 'h4', 56.00, 327.00),
  ('S004', 0, 'US02', 'CS02', 'h0', 126.00, 87.00),
  ('S004', 1, 'US02', 'CS04', 'h1', 126.00, 87.00),
  ('S004', 2, 'US02', 'CS02', 'h2', 146.00, 87.00),
  ('S004', 3, 'US02', 'CS02', 'h3', 136.00, 87.00),
  ('S005', 0, 'US02', 'CS02', 'h0', 262.00, 332.00),
  ('S005', 1, 'US02', 'CS04', 'h1', 262.00, 332.00),
  ('S005', 2, 'US02', 'CS02', 'h2', 242.00, 332.00),
  ('S006', 0, 'US01', 'CS01', 'h0', 372.00, 96.00),
  ('S006', 1, 'US01', 'CS04', 'h1', 372.00, 96.00),
  ('S006', 2, 'US01', 'CS04', 'h2', 352.00, 96.00),
  ('S006', 3, 'US01', 'CS01', 'h3', 352.00, 96.00),
  ('S007', 0, 'US01', 'CS01', 'h0', 459.00, 88.00),
  ('S007', 1, 'US03', 'CS02', 'h1', 479.00, 88.00),
  ('S007', 2, 'US03', 'CS03', 'h2', 459.00, 88.00),
  ('S007', 3, 'US01', 'CS04', 'h3', 469.00, 88.00),
  ('S007', 4, 'US03', 'CS02', 'h4', 469.00, 88.00);
