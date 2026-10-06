-- =====================================================================
-- Datos de DEMOSTRACIÓN (ficticios) para desarrollo y pruebas manuales
-- =====================================================================
-- Nombres, DNI y placas son inventados. Las rutas usan lugares reales de
-- la provincia de Moyobamba solo como referencia geográfica; las
-- duraciones y horarios son supuestos.
--
-- Usuarios de demostración (cambie las contraseñas o no cargue este
-- archivo fuera de un entorno local):
--   admin        / Admin2026     (administrador)
--   operaciones  / Opera2026     (encargado de operaciones)
--   jdespacho    / Despacho2026  (personal de despacho; usuario de HU-01)
--
-- Los servicios se crean para el día siguiente (CURDATE() + 1), de modo
-- que la demostración funciona cualquier día en que se cargue.
-- =====================================================================

SET NAMES utf8mb4;

INSERT INTO usuario (id, nombre_usuario, nombre_completo, hash_contrasena, rol) VALUES
  (1, 'admin',       'Administrador del sistema', 'pbkdf2_sha256$100000$2HOQmhPuuezbdbcisSE3dg==$MiEtAe5+gFg3Wk1DqQaJ3JSe3NInmZjucmSiY9KlEE8=', 'administrador'),
  (2, 'operaciones', 'Encargado de operaciones',  'pbkdf2_sha256$100000$z8ZoD85ZQChMKvC+63LTgA==$NNhP9BHj4UnntQ3zPlpxChQ+KEP/Lr8QzzqThmCr2sw=', 'operaciones'),
  (3, 'jdespacho',   'Personal de despacho',      'pbkdf2_sha256$100000$93BJbTcIdF13YjOkOI3FQA==$gPXTcC1Ym61N/f640nG+sYrMhHGOdyXYULOVEmuzMus=', 'despacho');

-- V: flota. V-06 está en mantenimiento, por lo que no pertenece a E_v.
INSERT INTO vehiculo (id, codigo, placa, capacidad, categoria, estado) VALUES
  (1, 'V-01', 'AHK-101', 15, 'M2', 'operativo'),
  (2, 'V-02', 'AHK-102', 15, 'M2', 'operativo'),
  (3, 'V-03', 'BJL-203',  4, 'M1', 'operativo'),
  (4, 'V-04', 'BJL-204',  4, 'M1', 'operativo'),
  (5, 'V-05', 'CKM-305', 30, 'M3', 'operativo'),
  (6, 'V-06', 'CKM-306', 15, 'M2', 'mantenimiento');

-- C: conductores. Turno T_c = 05:00–20:00 (300–1200 min), H_cmáx = 600 min.
-- C-06 tiene la licencia vencida y C-07 no está disponible: ninguno entra en E_c.
INSERT INTO conductor (id, codigo, dni, nombres, apellidos, categoria_licencia, vencimiento_licencia,
                       turno_inicio, turno_fin, minutos_acumulados, limite_minutos, disponible) VALUES
  (1, 'C-01', '70000001', 'Conductor', 'Demostración Uno',    'A-IIIa', DATE_ADD(CURDATE(), INTERVAL 2 YEAR), 300, 1200, 0, 600, TRUE),
  (2, 'C-02', '70000002', 'Conductor', 'Demostración Dos',    'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 300, 1200, 0, 600, TRUE),
  (3, 'C-03', '70000003', 'Conductor', 'Demostración Tres',   'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 3 YEAR), 300, 1200, 0, 600, TRUE),
  (4, 'C-04', '70000004', 'Conductor', 'Demostración Cuatro', 'A-IIa',  DATE_ADD(CURDATE(), INTERVAL 2 YEAR), 300, 1200, 0, 600, TRUE),
  (5, 'C-05', '70000005', 'Conductor', 'Demostración Cinco',  'A-IIIc', DATE_ADD(CURDATE(), INTERVAL 4 YEAR), 300, 1200, 0, 600, TRUE),
  (6, 'C-06', '70000006', 'Conductor', 'Demostración Seis',   'A-IIb',  DATE_SUB(CURDATE(), INTERVAL 10 DAY), 300, 1200, 0, 600, FALSE),
  (7, 'C-07', '70000007', 'Conductor', 'Demostración Siete',  'A-IIIa', DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 300, 1200, 0, 600, FALSE);

-- R: rutas autorizadas y compatibilidad κ(v, r).
INSERT INTO ruta (id, codigo, origen, destino, duracion_min, activa) VALUES
  (1, 'R-01', 'Soritor', 'Moyobamba', 50, TRUE),
  (2, 'R-02', 'Soritor', 'Tarapoto', 180, TRUE),
  (3, 'R-03', 'Soritor', 'Rioja',     95, TRUE);

INSERT INTO ruta_vehiculo (ruta_id, vehiculo_id) VALUES
  (1, 1), (1, 2), (1, 3), (1, 4), (1, 6),
  (2, 1), (2, 2), (2, 5), (2, 6),
  (3, 1), (3, 2), (3, 3), (3, 4), (3, 5);

-- H: salidas autorizadas (minutos desde la medianoche).
INSERT INTO salida_autorizada (ruta_id, hora, duracion_min) VALUES
  (1, 360, NULL), (1, 390, NULL), (1, 420, NULL), (1, 450, NULL), (1, 480, NULL), (1, 540, NULL),
  (1, 600, NULL), (1, 720, NULL), (1, 840, NULL), (1, 960, NULL), (1, 1020, NULL), (1, 1080, NULL),
  (2, 300, NULL), (2, 420, 190), (2, 540, NULL), (2, 780, NULL), (2, 900, NULL),
  (3, 360, NULL), (3, 450, NULL), (3, 570, NULL), (3, 690, NULL), (3, 870, NULL), (3, 990, NULL);

-- S: servicios pendientes del día siguiente (p_s: 3 alta, 2 media, 1 baja).
INSERT INTO servicio (codigo, fecha, ruta_id, hora_solicitada, prioridad, capacidad_requerida, creado_por) VALUES
  ('S-0001', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 360, 3, 4, 3),
  ('S-0002', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 2, 300, 3, 12, 3),
  ('S-0003', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 3, 360, 2, 4, 3),
  ('S-0004', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 420, 2, 10, 3),
  ('S-0005', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 2, 540, 2, 20, 3),
  ('S-0006', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 3, 570, 2, 8, 3),
  ('S-0007', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 600, 1, 4, 3),
  ('S-0008', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 720, 2, 4, 3),
  ('S-0009', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 3, 690, 1, 4, 3),
  ('S-0010', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 2, 780, 3, 15, 3),
  ('S-0011', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 960, 2, 12, 3),
  ('S-0012', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 3, 990, 1, 4, 3);
