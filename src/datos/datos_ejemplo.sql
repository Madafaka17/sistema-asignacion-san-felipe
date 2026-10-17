-- =====================================================================
-- Datos de ejemplo (FICTICIOS) para desarrollo y pruebas
-- Ejecutar después de esquema.sql:
--   mysql -u <usuario> -p san_felipe < src/datos/datos_ejemplo.sql
-- Nombres, DNI, placas y teléfonos son inventados.
-- =====================================================================
-- Casos incluidos a propósito para probar reglas y validaciones:
--   * SFB-204 está en mantenimiento        -> no entra a la programación
--   * Raúl Espinoza tiene licencia vencida -> no entra a la programación
--   * Martín Ruiz está de vacaciones       -> no entra a la programación
--   * Víctor Medina tiene licencia por vencer (en 2 meses)
--   * Hay salidas con demanda mayor que la capacidad de un minibús (30)
-- Las fechas de vencimiento son relativas a la fecha de carga, para que
-- estos casos sigan siendo válidos con el paso del tiempo.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- Vehículos: 4 minibuses (licencia A-IIb) y 4 ómnibus (licencia A-IIIa)
-- ---------------------------------------------------------------------
INSERT INTO vehiculo
    (placa, marca, modelo, anio_fabricacion, capacidad_pasajeros, categoria_licencia_requerida, estado)
VALUES
    ('SFA-101', 'Toyota',        'Coaster',  2019, 30, 'A-IIb',  'operativo'),
    ('SFA-102', 'Toyota',        'Coaster',  2020, 30, 'A-IIb',  'operativo'),
    ('SFA-103', 'Mercedes-Benz', 'Sprinter', 2021, 20, 'A-IIb',  'operativo'),
    ('SFA-104', 'Mercedes-Benz', 'Sprinter', 2021, 20, 'A-IIb',  'operativo'),
    ('SFB-201', 'Volvo',         'B290R',    2018, 50, 'A-IIIa', 'operativo'),
    ('SFB-202', 'Volvo',         'B290R',    2018, 50, 'A-IIIa', 'operativo'),
    ('SFB-203', 'Scania',        'K360',     2022, 50, 'A-IIIa', 'operativo'),
    ('SFB-204', 'Scania',        'K360',     2017, 50, 'A-IIIa', 'mantenimiento');

-- ---------------------------------------------------------------------
-- Conductores
-- ---------------------------------------------------------------------
INSERT INTO conductor
    (dni, nombres, apellidos, numero_licencia, categoria_licencia, fecha_vencimiento_licencia, telefono, estado)
VALUES
    ('70000001', 'Carlos',      'Quispe Huamán',   'Q70000001', 'A-IIIc', DATE_ADD(CURDATE(), INTERVAL 30 MONTH), '900000001', 'activo'),
    ('70000002', 'José Luis',   'Mamani Flores',   'Q70000002', 'A-IIIa', DATE_ADD(CURDATE(), INTERVAL 14 MONTH), '900000002', 'activo'),
    ('70000003', 'Miguel Ángel','Rojas Torres',    'Q70000003', 'A-IIIa', DATE_ADD(CURDATE(), INTERVAL 20 MONTH), '900000003', 'activo'),
    ('70000004', 'Juan Carlos', 'Gutiérrez Vega',  'Q70000004', 'A-IIIa', DATE_ADD(CURDATE(), INTERVAL 10 MONTH), '900000004', 'activo'),
    ('70000005', 'Luis Alberto','Chávez Ramos',    'Q70000005', 'A-IIb',  DATE_ADD(CURDATE(), INTERVAL  8 MONTH), '900000005', 'activo'),
    ('70000006', 'Pedro Pablo', 'Sánchez Díaz',    'Q70000006', 'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 16 MONTH), '900000006', 'activo'),
    ('70000007', 'Jorge',       'Castillo Mendoza','Q70000007', 'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 12 MONTH), '900000007', 'activo'),
    ('70000008', 'Ricardo',     'Vargas Paredes',  'Q70000008', 'A-IIIc', DATE_ADD(CURDATE(), INTERVAL 36 MONTH), NULL,        'activo'),
    ('70000009', 'Fernando',    'Herrera Cruz',    'Q70000009', 'A-IIIa', DATE_ADD(CURDATE(), INTERVAL 24 MONTH), '900000009', 'activo'),
    ('70000010', 'Víctor Hugo', 'Medina Salazar',  'Q70000010', 'A-IIb',  DATE_ADD(CURDATE(), INTERVAL  2 MONTH), '900000010', 'activo'),
    ('70000011', 'Raúl',        'Espinoza León',   'Q70000011', 'A-IIIa', DATE_SUB(CURDATE(), INTERVAL  1 MONTH), '900000011', 'activo'),
    ('70000012', 'Martín',      'Ruiz Castro',     'Q70000012', 'A-IIb',  DATE_ADD(CURDATE(), INTERVAL 18 MONTH), '900000012', 'vacaciones');

-- ---------------------------------------------------------------------
-- Rutas (duracion_min = salida del terminal hasta regreso al terminal)
-- ---------------------------------------------------------------------
INSERT INTO ruta (id_ruta, codigo, nombre, origen, destino, distancia_km, duracion_min) VALUES
    (1, 'R01', 'Circuito Centro',       'Terminal principal', 'Zona Centro',   18.5,  90),
    (2, 'R02', 'Circuito Norte',        'Terminal principal', 'Zona Norte',    26.0, 120),
    (3, 'R03', 'Servicio interurbano',  'Terminal principal', 'Ciudad vecina', 75.0, 180);

-- ---------------------------------------------------------------------
-- Horarios: de lunes a sábado se generan 18 salidas por día; el domingo, 14.
-- ---------------------------------------------------------------------
SET @todos   = 'LUN,MAR,MIE,JUE,VIE,SAB,DOM';
SET @lun_sab = 'LUN,MAR,MIE,JUE,VIE,SAB';

INSERT INTO horario (id_ruta, hora_salida, dias_operacion, demanda_estimada) VALUES
    -- R01 Circuito Centro
    (1, '06:00', @todos,   40),
    (1, '07:00', @lun_sab, 45),
    (1, '08:00', @todos,   35),
    (1, '10:00', @todos,   20),
    (1, '12:00', @todos,   25),
    (1, '14:00', @lun_sab, 25),
    (1, '16:00', @todos,   30),
    (1, '17:00', @lun_sab, 45),
    (1, '18:00', @todos,   50),
    (1, '19:00', @todos,   35),
    -- R02 Circuito Norte
    (2, '06:30', @todos,   35),
    (2, '08:30', @todos,   30),
    (2, '11:00', @lun_sab, 20),
    (2, '13:30', @todos,   25),
    (2, '16:00', @todos,   30),
    (2, '18:30', @todos,   40),
    -- R03 Servicio interurbano
    (3, '07:00', @todos,   45),
    (3, '13:00', @lun_sab, 40),
    (3, '15:00', 'DOM',    50);
