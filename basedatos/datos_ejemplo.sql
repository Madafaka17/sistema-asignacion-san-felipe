-- =====================================================================
-- Datos de DEMOSTRACIÓN (ficticios) para desarrollo y pruebas manuales
-- =====================================================================
-- Nombres, DNI y placas son inventados. La estructura sigue la operación
-- declarada por la empresa (sección 3.1.2 de la tesis y PROTOCOLO.md del
-- experimento): desde el terminal de Soritor salen viajes redondos a
-- Moyobamba (ida declarada de 30 min) y a Tarapoto (150 min), por orden de
-- llegada en la cola de cada destino, con unidades de 16 asientos, un
-- conductor habitual por unidad y reemplazos autorizados.
--
-- Valores que NO provienen de la empresa (supuestos de demostración):
-- la duración del ciclo = 2 × ida + 30 min de estancia (90 y 330 min), las
-- horas de salida autorizadas, los turnos, los límites de conducción y las
-- llegadas a la cola.
--
-- Usuarios de demostración (cambie las contraseñas o no cargue este
-- archivo fuera de un entorno local):
--   admin        / Admin2026     (administrador)
--   operaciones  / Opera2026     (encargado de operaciones)
--   jdespacho    / Despacho2026  (personal de despacho; usuario de HU-01)
--
-- Los servicios y las colas son del día siguiente (CURDATE() + 1), de modo
-- que la demostración funciona cualquier día en que se cargue.
-- =====================================================================

SET NAMES utf8mb4;

INSERT INTO usuario (id, nombre_usuario, nombre_completo, hash_contrasena, rol) VALUES
  (1, 'admin',       'Administrador del sistema', 'pbkdf2_sha256$100000$2HOQmhPuuezbdbcisSE3dg==$MiEtAe5+gFg3Wk1DqQaJ3JSe3NInmZjucmSiY9KlEE8=', 'administrador'),
  (2, 'operaciones', 'Encargado de operaciones',  'pbkdf2_sha256$100000$z8ZoD85ZQChMKvC+63LTgA==$NNhP9BHj4UnntQ3zPlpxChQ+KEP/Lr8QzzqThmCr2sw=', 'operaciones'),
  (3, 'jdespacho',   'Personal de despacho',      'pbkdf2_sha256$100000$93BJbTcIdF13YjOkOI3FQA==$gPXTcC1Ym61N/f640nG+sYrMhHGOdyXYULOVEmuzMus=', 'despacho');

-- V: flota homogénea de 16 asientos (leído en los manifiestos, Anexo B).
-- V-10 entró a mantenimiento después de formar cola: no pertenece a E_v.
INSERT INTO vehiculo (id, codigo, placa, capacidad, categoria, estado) VALUES
  (1,  'V-01', 'AHK-101', 16, 'M2', 'operativo'),
  (2,  'V-02', 'AHK-102', 16, 'M2', 'operativo'),
  (3,  'V-03', 'AHK-103', 16, 'M2', 'operativo'),
  (4,  'V-04', 'AHK-104', 16, 'M2', 'operativo'),
  (5,  'V-05', 'BJL-205', 16, 'M2', 'operativo'),
  (6,  'V-06', 'BJL-206', 16, 'M2', 'operativo'),
  (7,  'V-07', 'BJL-207', 16, 'M2', 'operativo'),
  (8,  'V-08', 'BJL-208', 16, 'M2', 'operativo'),
  (9,  'V-09', 'CKM-309', 16, 'M2', 'operativo'),
  (10, 'V-10', 'CKM-310', 16, 'M2', 'mantenimiento');

-- C: conductores. Turno T_c = 04:30–19:30 (270–1170 min) y H_cmáx = 600 min,
-- salvo C-04, que entra a las 08:00. C-10 no está disponible, la licencia
-- de C-11 venció y la de C-12 (A-IIa) no habilita la categoría M2.
INSERT INTO conductor (id, codigo, dni, nombres, apellidos, categoria_licencia, vencimiento_licencia,
                       turno_inicio, turno_fin, minutos_acumulados, limite_minutos, disponible) VALUES
  (1,  'C-01', '70000001', 'Conductor', 'Demostración Uno',    'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 2 YEAR), 270, 1170, 0, 600, TRUE),
  (2,  'C-02', '70000002', 'Conductor', 'Demostración Dos',    'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 270, 1170, 0, 600, TRUE),
  (3,  'C-03', '70000003', 'Conductor', 'Demostración Tres',   'A-IIIa', DATE_ADD(CURDATE(), INTERVAL 3 YEAR), 270, 1170, 0, 600, TRUE),
  (4,  'C-04', '70000004', 'Conductor', 'Demostración Cuatro', 'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 2 YEAR), 480, 1170, 0, 600, TRUE),
  (5,  'C-05', '70000005', 'Conductor', 'Demostración Cinco',  'A-IIIc', DATE_ADD(CURDATE(), INTERVAL 4 YEAR), 270, 1170, 0, 600, TRUE),
  (6,  'C-06', '70000006', 'Conductor', 'Demostración Seis',   'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 270, 1170, 0, 600, TRUE),
  (7,  'C-07', '70000007', 'Conductor', 'Demostración Siete',  'A-IIIa', DATE_ADD(CURDATE(), INTERVAL 2 YEAR), 270, 1170, 0, 600, TRUE),
  (8,  'C-08', '70000008', 'Conductor', 'Demostración Ocho',   'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 3 YEAR), 270, 1170, 0, 600, TRUE),
  (9,  'C-09', '70000009', 'Conductor', 'Demostración Nueve',  'A-IIIa', DATE_ADD(CURDATE(), INTERVAL 2 YEAR), 270, 1170, 0, 600, TRUE),
  (10, 'C-10', '70000010', 'Conductor', 'Demostración Diez',   'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 270, 1170, 0, 600, FALSE),
  (11, 'C-11', '70000011', 'Conductor', 'Demostración Once',   'A-IIb',  DATE_SUB(CURDATE(), INTERVAL 10 DAY), 270, 1170, 0, 600, FALSE),
  (12, 'C-12', '70000012', 'Conductor', 'Demostración Doce',   'A-IIa',  DATE_ADD(CURDATE(), INTERVAL 2 YEAR), 270, 1170, 0, 600, TRUE);

-- chab(v) y C_v^R. V-09 no tiene conductor habitual.
INSERT INTO par_autorizado (vehiculo_id, conductor_id, tipo) VALUES
  (1, 1, 'habitual'),  (1, 9, 'reemplazo'),
  (2, 2, 'habitual'),  (2, 9, 'reemplazo'),
  (3, 3, 'habitual'),  (3, 10, 'reemplazo'),
  (4, 4, 'habitual'),  (4, 9, 'reemplazo'),
  (5, 5, 'habitual'),  (5, 9, 'reemplazo'), (5, 11, 'reemplazo'),
  (6, 6, 'habitual'),  (6, 9, 'reemplazo'),
  (7, 7, 'habitual'),  (7, 12, 'reemplazo'),
  (8, 8, 'habitual'),  (8, 9, 'reemplazo'),
  (9, 8, 'reemplazo'), (9, 9, 'reemplazo'),
  (10, 10, 'habitual'), (10, 9, 'reemplazo');

-- R: rutas desde Soritor. duracion_min = ciclo (ida, estancia y retorno);
-- ida_min = ida declarada, referencia por validar.
INSERT INTO ruta (id, codigo, origen, destino, duracion_min, ida_min, activa) VALUES
  (1, 'R-01', 'Soritor', 'Moyobamba',  90,  30, TRUE),
  (2, 'R-02', 'Soritor', 'Tarapoto',  330, 150, TRUE);

INSERT INTO ruta_vehiculo (ruta_id, vehiculo_id) VALUES
  (1, 1), (1, 2), (1, 3), (1, 4), (1, 9),
  (2, 5), (2, 6), (2, 7), (2, 8), (2, 9), (2, 10);

-- H: salidas autorizadas cada 30 min (minutos desde la medianoche):
-- Moyobamba de 06:00 a 17:30 y Tarapoto de 05:00 a 12:00.
INSERT INTO salida_autorizada (ruta_id, hora) VALUES
  (1, 360), (1, 390), (1, 420), (1, 450), (1, 480), (1, 510), (1, 540), (1, 570),
  (1, 600), (1, 630), (1, 660), (1, 690), (1, 720), (1, 750), (1, 780), (1, 810),
  (1, 840), (1, 870), (1, 900), (1, 930), (1, 960), (1, 990), (1, 1020), (1, 1050),
  (2, 300), (2, 330), (2, 360), (2, 390), (2, 420), (2, 450), (2, 480), (2, 510),
  (2, 540), (2, 570), (2, 600), (2, 630), (2, 660), (2, 690), (2, 720);

-- Colas del día siguiente, por orden de llegada (π). Las llegadas de las
-- 07:30 en adelante son retornos previstos de la misma unidad.
INSERT INTO cola (id, ruta_id, fecha) VALUES
  (1, 1, DATE_ADD(CURDATE(), INTERVAL 1 DAY)),
  (2, 2, DATE_ADD(CURDATE(), INTERVAL 1 DAY));

INSERT INTO entrada_cola (id, cola_id, vehiculo_id, posicion, llegada, registrado_por) VALUES
  -- Moyobamba: las posiciones 8 y 10 quedan libres para registrar servicios.
  (1,  1, 1, 1,  320, 3), (2,  1, 2, 2,  325, 3), (3,  1, 3, 3,  330, 3), (4,  1, 4, 4,  340, 3),
  (5,  1, 1, 5,  450, 3), (6,  1, 2, 6,  480, 3), (7,  1, 3, 7,  510, 3), (8,  1, 4, 8,  540, 3),
  (9,  1, 1, 9,  630, 3), (10, 1, 2, 10, 690, 3),
  -- Tarapoto: V-10 formó cola y luego entró a mantenimiento.
  (11, 2, 5, 1,  280, 3), (12, 2, 10, 2, 285, 3), (13, 2, 6, 3,  290, 3), (14, 2, 7, 4,  300, 3),
  (15, 2, 5, 5,  630, 3), (16, 2, 8, 6,  640, 3);

-- S: servicios pendientes del día siguiente (p_s: 3 alta, 2 media, 1 baja),
-- cada uno con su turno en la cola. La hora solicitada es la salida nominal.
INSERT INTO servicio (codigo, fecha, ruta_id, hora_solicitada, prioridad, capacidad_requerida, entrada_cola_id, creado_por) VALUES
  ('S-0001', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 360, 3, 14, 1,  3),
  ('S-0002', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 2, 300, 3, 16, 11, 3),
  ('S-0003', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 390, 2, 12, 2,  3),
  ('S-0004', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 420, 2, 10, 3,  3),
  ('S-0005', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 2, 360, 2, 16, 12, 3),
  ('S-0006', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 450, 1, 8,  4,  3),
  ('S-0007', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 2, 420, 2, 15, 13, 3),
  ('S-0008', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 540, 2, 12, 5,  3),
  ('S-0009', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 600, 2, 9,  6,  3),
  ('S-0010', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 2, 660, 3, 16, 15, 3),
  ('S-0011', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 780, 1, 6,  7,  3),
  ('S-0012', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 900, 2, 11, 9,  3);
