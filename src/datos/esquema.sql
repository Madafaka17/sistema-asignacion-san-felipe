-- =====================================================================
-- Esquema de base de datos
-- Sistema de Asignación de Recursos - Transporte y Turismo San Felipe S.A.C.
-- Motor: MySQL 8.4 (InnoDB, utf8mb4)
-- =====================================================================
-- El script se ejecuta sobre la base de datos seleccionada:
--   mysql -u <usuario> -p san_felipe < src/datos/esquema.sql
-- Con docker compose se carga automáticamente al crear el contenedor.
-- Descripción de cada tabla: docs/metodos_modelos_algoritmos.md
--
-- ADVERTENCIA: el script BORRA y vuelve a crear todas las tablas.
-- No lo ejecute sobre una base de datos con información real.
-- =====================================================================

SET NAMES utf8mb4;

-- Se eliminan en orden inverso a las dependencias para poder recrear.
DROP VIEW  IF EXISTS v_asignacion_detalle;
DROP TABLE IF EXISTS historial_aptitud;
DROP TABLE IF EXISTS asignacion;
DROP TABLE IF EXISTS programacion;
DROP TABLE IF EXISTS horario;
DROP TABLE IF EXISTS ruta;
DROP TABLE IF EXISTS conductor;
DROP TABLE IF EXISTS vehiculo;
DROP TABLE IF EXISTS categoria_licencia;
DROP TABLE IF EXISTS usuario;

-- ---------------------------------------------------------------------
-- Usuarios del sistema (inicio de sesión y roles)
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
    id_usuario       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nombre_usuario   VARCHAR(50)   NOT NULL,
    nombre_completo  VARCHAR(120)  NOT NULL,
    hash_contrasena  VARCHAR(255)  NOT NULL COMMENT 'pbkdf2_sha256$iteraciones$sal$hash; nunca texto plano',
    rol              ENUM('administrador', 'operador') NOT NULL DEFAULT 'operador',
    activo           BOOLEAN       NOT NULL DEFAULT TRUE,
    ultimo_acceso    DATETIME      NULL,
    creado_en        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario),
    UNIQUE KEY uq_usuario_nombre (nombre_usuario)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Catálogo de categorías de licencia de conducir (transporte de pasajeros)
-- "nivel" ordena las categorías: un conductor puede manejar un vehículo
-- si nivel(licencia del conductor) >= nivel(licencia que exige el vehículo).
-- ---------------------------------------------------------------------
CREATE TABLE categoria_licencia (
    codigo       VARCHAR(6)        NOT NULL,
    nivel        TINYINT UNSIGNED  NOT NULL,
    descripcion  VARCHAR(120)      NOT NULL,
    PRIMARY KEY (codigo),
    UNIQUE KEY uq_categoria_nivel (nivel)
) ENGINE = InnoDB;

INSERT INTO categoria_licencia (codigo, nivel, descripcion) VALUES
    ('A-IIb',  1, 'Microbuses y minibuses de transporte de pasajeros'),
    ('A-IIIa', 2, 'Ómnibus de transporte de pasajeros'),
    ('A-IIIc', 3, 'Categoría profesional más alta (habilita las anteriores)');

-- ---------------------------------------------------------------------
-- Flota de vehículos
-- ---------------------------------------------------------------------
CREATE TABLE vehiculo (
    id_vehiculo                   INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    placa                         VARCHAR(7)        NOT NULL COMMENT 'Formato ABC-123',
    marca                         VARCHAR(40)       NOT NULL,
    modelo                        VARCHAR(40)       NOT NULL,
    anio_fabricacion              SMALLINT UNSIGNED NOT NULL,
    capacidad_pasajeros           SMALLINT UNSIGNED NOT NULL,
    categoria_licencia_requerida  VARCHAR(6)        NOT NULL,
    estado                        ENUM('operativo', 'mantenimiento', 'inactivo') NOT NULL DEFAULT 'operativo',
    creado_en                     DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en                DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_vehiculo),
    UNIQUE KEY uq_vehiculo_placa (placa),
    KEY ix_vehiculo_estado (estado),
    CONSTRAINT fk_vehiculo_categoria FOREIGN KEY (categoria_licencia_requerida)
        REFERENCES categoria_licencia (codigo),
    CONSTRAINT ck_vehiculo_capacidad CHECK (capacidad_pasajeros > 0),
    CONSTRAINT ck_vehiculo_anio      CHECK (anio_fabricacion >= 1980)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Conductores
-- ---------------------------------------------------------------------
CREATE TABLE conductor (
    id_conductor                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    dni                         CHAR(8)       NOT NULL,
    nombres                     VARCHAR(60)   NOT NULL,
    apellidos                   VARCHAR(80)   NOT NULL,
    numero_licencia             VARCHAR(12)   NOT NULL,
    categoria_licencia          VARCHAR(6)    NOT NULL,
    fecha_vencimiento_licencia  DATE          NOT NULL,
    telefono                    VARCHAR(15)   NULL,
    estado                      ENUM('activo', 'vacaciones', 'descanso_medico', 'inactivo') NOT NULL DEFAULT 'activo',
    creado_en                   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_conductor),
    UNIQUE KEY uq_conductor_dni (dni),
    UNIQUE KEY uq_conductor_licencia (numero_licencia),
    KEY ix_conductor_estado (estado),
    CONSTRAINT fk_conductor_categoria FOREIGN KEY (categoria_licencia)
        REFERENCES categoria_licencia (codigo),
    CONSTRAINT ck_conductor_dni CHECK (dni REGEXP '^[0-9]{8}$')
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Rutas que opera la empresa
-- duracion_min: tiempo total del servicio, desde que el vehículo sale
-- del terminal hasta que regresa y queda libre para otra salida.
-- ---------------------------------------------------------------------
CREATE TABLE ruta (
    id_ruta       INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    codigo        VARCHAR(10)       NOT NULL,
    nombre        VARCHAR(100)      NOT NULL,
    origen        VARCHAR(80)       NOT NULL,
    destino       VARCHAR(80)       NOT NULL,
    distancia_km  DECIMAL(6, 1)     NOT NULL,
    duracion_min  SMALLINT UNSIGNED NOT NULL,
    activa        BOOLEAN           NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id_ruta),
    UNIQUE KEY uq_ruta_codigo (codigo),
    CONSTRAINT ck_ruta_distancia CHECK (distancia_km > 0),
    CONSTRAINT ck_ruta_duracion  CHECK (duracion_min > 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Horarios: salidas recurrentes de una ruta.
-- Cada horario activo cuyo día de operación coincide con la fecha
-- programada genera una "salida" que el algoritmo debe cubrir.
-- ---------------------------------------------------------------------
CREATE TABLE horario (
    id_horario        INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    id_ruta           INT UNSIGNED      NOT NULL,
    hora_salida       TIME              NOT NULL,
    dias_operacion    SET('LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB', 'DOM') NOT NULL,
    demanda_estimada  SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Pasajeros esperados por salida',
    activo            BOOLEAN           NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id_horario),
    UNIQUE KEY uq_horario_ruta_hora (id_ruta, hora_salida),
    CONSTRAINT fk_horario_ruta FOREIGN KEY (id_ruta) REFERENCES ruta (id_ruta)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Programación operativa: una ejecución del algoritmo genético para una
-- fecha. Guarda métricas y los parámetros usados (reproducibilidad).
-- Solo puede existir una programación aprobada por fecha.
-- ---------------------------------------------------------------------
CREATE TABLE programacion (
    id_programacion          INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    fecha_operacion          DATE           NOT NULL,
    estado                   ENUM('borrador', 'aprobada', 'anulada') NOT NULL DEFAULT 'borrador',
    aptitud                  DOUBLE         NOT NULL COMMENT 'Aptitud del mejor individuo, entre 0 y 1',
    violaciones_duras        INT UNSIGNED   NOT NULL DEFAULT 0,
    penalizacion_blanda      DOUBLE         NOT NULL DEFAULT 0,
    generaciones_ejecutadas  INT UNSIGNED   NOT NULL,
    tiempo_ejecucion_s       DECIMAL(10, 3) NOT NULL,
    semilla                  INT UNSIGNED   NULL,
    parametros               JSON           NOT NULL COMMENT 'Copia de config/parametros_ga.yaml usada',
    creado_por               INT UNSIGNED   NULL,
    creado_en                DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    aprobado_en              DATETIME       NULL,
    -- Columna auxiliar: vale la fecha solo si está aprobada (NULL si no),
    -- así el índice único impide dos programaciones aprobadas el mismo día.
    fecha_aprobada           DATE AS (IF(estado = 'aprobada', fecha_operacion, NULL)) STORED,
    PRIMARY KEY (id_programacion),
    UNIQUE KEY uq_programacion_aprobada (fecha_aprobada),
    KEY ix_programacion_fecha (fecha_operacion),
    CONSTRAINT fk_programacion_usuario FOREIGN KEY (creado_por)
        REFERENCES usuario (id_usuario) ON DELETE SET NULL,
    CONSTRAINT ck_programacion_aptitud CHECK (aptitud >= 0 AND aptitud <= 1)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Asignaciones: resultado decodificado del mejor cromosoma.
-- Una fila por salida: qué vehículo y qué conductor la cubren.
-- ---------------------------------------------------------------------
CREATE TABLE asignacion (
    id_asignacion    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_programacion  INT UNSIGNED NOT NULL,
    id_horario       INT UNSIGNED NOT NULL,
    id_vehiculo      INT UNSIGNED NOT NULL,
    id_conductor     INT UNSIGNED NOT NULL,
    inicio           DATETIME     NOT NULL,
    fin              DATETIME     NOT NULL,
    PRIMARY KEY (id_asignacion),
    UNIQUE KEY uq_asignacion_salida (id_programacion, id_horario),
    KEY ix_asignacion_vehiculo  (id_programacion, id_vehiculo, inicio),
    KEY ix_asignacion_conductor (id_programacion, id_conductor, inicio),
    CONSTRAINT fk_asignacion_programacion FOREIGN KEY (id_programacion)
        REFERENCES programacion (id_programacion) ON DELETE CASCADE,
    CONSTRAINT fk_asignacion_horario   FOREIGN KEY (id_horario)   REFERENCES horario (id_horario),
    CONSTRAINT fk_asignacion_vehiculo  FOREIGN KEY (id_vehiculo)  REFERENCES vehiculo (id_vehiculo),
    CONSTRAINT fk_asignacion_conductor FOREIGN KEY (id_conductor) REFERENCES conductor (id_conductor),
    CONSTRAINT ck_asignacion_intervalo CHECK (fin > inicio)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Historial de aptitud por generación (curva de convergencia)
-- ---------------------------------------------------------------------
CREATE TABLE historial_aptitud (
    id_programacion   INT UNSIGNED NOT NULL,
    generacion        INT UNSIGNED NOT NULL,
    mejor_aptitud     DOUBLE       NOT NULL,
    aptitud_promedio  DOUBLE       NOT NULL,
    PRIMARY KEY (id_programacion, generacion),
    CONSTRAINT fk_historial_programacion FOREIGN KEY (id_programacion)
        REFERENCES programacion (id_programacion) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Vista para reportes: asignaciones con datos legibles
-- ---------------------------------------------------------------------
CREATE VIEW v_asignacion_detalle AS
SELECT
    p.id_programacion,
    p.fecha_operacion,
    p.estado                                   AS estado_programacion,
    r.codigo                                   AS codigo_ruta,
    r.nombre                                   AS ruta,
    a.inicio,
    a.fin,
    TIMESTAMPDIFF(MINUTE, a.inicio, a.fin)     AS duracion_min,
    v.placa,
    v.capacidad_pasajeros,
    h.demanda_estimada,
    c.dni                                      AS dni_conductor,
    CONCAT(c.apellidos, ', ', c.nombres)       AS conductor
FROM asignacion a
JOIN programacion p ON p.id_programacion = a.id_programacion
JOIN horario      h ON h.id_horario      = a.id_horario
JOIN ruta         r ON r.id_ruta         = h.id_ruta
JOIN vehiculo     v ON v.id_vehiculo     = a.id_vehiculo
JOIN conductor    c ON c.id_conductor    = a.id_conductor;
