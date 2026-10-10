-- =====================================================================
-- Esquema de la base de datos
-- Sistema de asignación de recursos - Transportes y Turismo San Felipe S.A.C.
-- Motor: MySQL 8.4 (InnoDB, utf8mb4)
-- =====================================================================
-- Cada tabla corresponde a un conjunto o parámetro de la Tabla 11 de la
-- tesis (ver docs/modelo_datos.md). Las horas se guardan como minutos desde
-- la medianoche, t ∈ [0, 1440), igual que en el modelo matemático.
--
-- Se ejecuta sobre la base de datos seleccionada; con docker compose se
-- carga sola al crear el contenedor.
--
-- ADVERTENCIA: BORRA y vuelve a crear todas las tablas.
-- =====================================================================

SET NAMES utf8mb4;

DROP VIEW  IF EXISTS v_asignacion_detalle;
DROP TABLE IF EXISTS bitacora;
DROP TABLE IF EXISTS incidencia;
DROP TABLE IF EXISTS historial_aptitud;
DROP TABLE IF EXISTS asignacion;
DROP TABLE IF EXISTS programacion;
DROP TABLE IF EXISTS servicio;
DROP TABLE IF EXISTS salida_autorizada;
DROP TABLE IF EXISTS ruta_vehiculo;
DROP TABLE IF EXISTS ruta;
DROP TABLE IF EXISTS conductor;
DROP TABLE IF EXISTS vehiculo;
DROP TABLE IF EXISTS sesion;
DROP TABLE IF EXISTS usuario;

-- ---------------------------------------------------------------------
-- Usuarios y sesiones (HU-01, RNF-06)
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
    id                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre_usuario     VARCHAR(50)  NOT NULL,
    nombre_completo    VARCHAR(120) NOT NULL,
    hash_contrasena    VARCHAR(255) NOT NULL COMMENT 'pbkdf2_sha256$iteraciones$sal$hash',
    rol                ENUM('despacho', 'operaciones', 'administrador') NOT NULL,
    activo             BOOLEAN      NOT NULL DEFAULT TRUE,
    intentos_fallidos  TINYINT UNSIGNED NOT NULL DEFAULT 0,
    bloqueado_hasta    DATETIME     NULL,
    creado_en          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_usuario_nombre (nombre_usuario)
) ENGINE = InnoDB;

-- Tokens de actualización: se guarda su resumen SHA-256, nunca el token.
CREATE TABLE sesion (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    usuario_id  INT UNSIGNED NOT NULL,
    hash_token  CHAR(64)     NOT NULL,
    expira_en   DATETIME     NOT NULL,
    revocada    BOOLEAN      NOT NULL DEFAULT FALSE,
    creado_en   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_sesion_token (hash_token),
    CONSTRAINT fk_sesion_usuario FOREIGN KEY (usuario_id) REFERENCES usuario (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- V: vehículos (HU-02). capacidad = Q_v; estado define E_v.
-- ---------------------------------------------------------------------
CREATE TABLE vehiculo (
    id              INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    codigo          VARCHAR(10)       NOT NULL,
    placa           VARCHAR(7)        NOT NULL,
    capacidad       SMALLINT UNSIGNED NOT NULL,
    categoria       ENUM('M1', 'M2', 'M3') NOT NULL,
    estado          ENUM('operativo', 'mantenimiento', 'inactivo') NOT NULL DEFAULT 'operativo',
    creado_en       DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en  DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehiculo_codigo (codigo),
    UNIQUE KEY uq_vehiculo_placa (placa),
    CONSTRAINT ck_vehiculo_capacidad CHECK (capacidad > 0),
    CONSTRAINT ck_vehiculo_placa CHECK (placa REGEXP '^[A-Z0-9]{3}-[0-9]{3}$')
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- C: conductores (HU-03).
-- turno_inicio–turno_fin = T_c; minutos_acumulados = H_c0;
-- limite_minutos = H_cmáx; disponible y la licencia vigente definen E_c.
-- ---------------------------------------------------------------------
CREATE TABLE conductor (
    id                    INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    codigo                VARCHAR(10)       NOT NULL,
    dni                   CHAR(8)           NOT NULL,
    nombres               VARCHAR(60)       NOT NULL,
    apellidos             VARCHAR(80)       NOT NULL,
    categoria_licencia    ENUM('A-IIa', 'A-IIb', 'A-IIIa', 'A-IIIb', 'A-IIIc') NOT NULL,
    vencimiento_licencia  DATE              NOT NULL,
    turno_inicio          SMALLINT UNSIGNED NOT NULL,
    turno_fin             SMALLINT UNSIGNED NOT NULL,
    minutos_acumulados    INT UNSIGNED      NOT NULL DEFAULT 0,
    limite_minutos        INT UNSIGNED      NOT NULL,
    disponible            BOOLEAN           NOT NULL DEFAULT TRUE,
    creado_en             DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en        DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_conductor_codigo (codigo),
    UNIQUE KEY uq_conductor_dni (dni),
    CONSTRAINT ck_conductor_dni CHECK (dni REGEXP '^[0-9]{8}$'),
    CONSTRAINT ck_conductor_turno CHECK (turno_inicio < turno_fin AND turno_fin <= 1440),
    CONSTRAINT ck_conductor_limite CHECK (limite_minutos > 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- R: rutas autorizadas (HU-04) y compatibilidad κ(v, r) (relación N:M)
-- ---------------------------------------------------------------------
CREATE TABLE ruta (
    id            INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    codigo        VARCHAR(10)       NOT NULL,
    origen        VARCHAR(80)       NOT NULL,
    destino       VARCHAR(80)       NOT NULL,
    duracion_min  SMALLINT UNSIGNED NOT NULL,
    activa        BOOLEAN           NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_ruta_codigo (codigo),
    CONSTRAINT ck_ruta_duracion CHECK (duracion_min > 0)
) ENGINE = InnoDB;

CREATE TABLE ruta_vehiculo (
    ruta_id      INT UNSIGNED NOT NULL,
    vehiculo_id  INT UNSIGNED NOT NULL,
    PRIMARY KEY (ruta_id, vehiculo_id),
    CONSTRAINT fk_rv_ruta     FOREIGN KEY (ruta_id)     REFERENCES ruta (id)     ON DELETE CASCADE,
    CONSTRAINT fk_rv_vehiculo FOREIGN KEY (vehiculo_id) REFERENCES vehiculo (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Salidas autorizadas de cada ruta (HU-05): elementos de H_s.
-- duracion_min opcional: d_{s,h} cuando difiere de la duración de la ruta.
-- ---------------------------------------------------------------------
CREATE TABLE salida_autorizada (
    id            INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    ruta_id       INT UNSIGNED      NOT NULL,
    hora          SMALLINT UNSIGNED NOT NULL,
    duracion_min  SMALLINT UNSIGNED NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_salida_ruta_hora (ruta_id, hora),
    CONSTRAINT fk_salida_ruta FOREIGN KEY (ruta_id) REFERENCES ruta (id),
    CONSTRAINT ck_salida_hora CHECK (hora < 1440),
    CONSTRAINT ck_salida_duracion CHECK (duracion_min IS NULL OR duracion_min > 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- S: servicios programados (HU-06). r(s) = ruta_id, p_s = prioridad,
-- q_s = capacidad_requerida. La clave foránea compuesta garantiza que la
-- hora solicitada sea una salida autorizada de la ruta.
-- ---------------------------------------------------------------------
CREATE TABLE servicio (
    id                   INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    codigo               VARCHAR(12)       NOT NULL,
    fecha                DATE              NOT NULL,
    ruta_id              INT UNSIGNED      NOT NULL,
    hora_solicitada      SMALLINT UNSIGNED NOT NULL,
    prioridad            TINYINT UNSIGNED  NOT NULL,
    capacidad_requerida  SMALLINT UNSIGNED NOT NULL,
    estado               ENUM('pendiente', 'programado', 'cancelado') NOT NULL DEFAULT 'pendiente',
    creado_por           INT UNSIGNED      NULL,
    creado_en            DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_servicio_codigo (codigo),
    KEY ix_servicio_fecha_estado (fecha, estado),
    CONSTRAINT fk_servicio_salida FOREIGN KEY (ruta_id, hora_solicitada)
        REFERENCES salida_autorizada (ruta_id, hora),
    CONSTRAINT fk_servicio_usuario FOREIGN KEY (creado_por) REFERENCES usuario (id) ON DELETE SET NULL,
    CONSTRAINT ck_servicio_prioridad CHECK (prioridad BETWEEN 1 AND 3),
    CONSTRAINT ck_servicio_capacidad CHECK (capacidad_requerida > 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- X: programaciones generadas (HU-07) con F(X), Φ(X) y sus componentes.
-- Cada ejecución se guarda como un registro nuevo; solo puede haber una
-- programación aprobada por fecha (índice único sobre fecha_aprobada).
-- ---------------------------------------------------------------------
CREATE TABLE programacion (
    id                      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    fecha                   DATE          NOT NULL,
    estado                  ENUM('propuesta', 'aprobada', 'reemplazada', 'descartada') NOT NULL DEFAULT 'propuesta',
    metodo                  VARCHAR(40)   NOT NULL,
    aptitud                 DOUBLE        NOT NULL COMMENT 'F(X) de la mejor solución',
    phi                     INT UNSIGNED  NOT NULL COMMENT 'Φ(X) de la mejor solución',
    phi_validador           INT UNSIGNED  NOT NULL COMMENT 'Φ recalculado sobre las asignaciones vigentes',
    conflictos_vehiculo     INT UNSIGNED  NOT NULL DEFAULT 0,
    conflictos_conductor    INT UNSIGNED  NOT NULL DEFAULT 0,
    conductores_excedidos   INT UNSIGNED  NOT NULL DEFAULT 0,
    exceso_min              INT UNSIGNED  NOT NULL DEFAULT 0,
    retraso_min             INT UNSIGNED  NOT NULL DEFAULT 0,
    reprogramados           INT UNSIGNED  NOT NULL DEFAULT 0,
    tiempo_muerto_min       INT UNSIGNED  NOT NULL DEFAULT 0,
    desviacion_carga        DOUBLE        NOT NULL DEFAULT 0,
    perdida                 DOUBLE        NOT NULL DEFAULT 0,
    generaciones            INT UNSIGNED  NOT NULL DEFAULT 0,
    tiempo_ms               INT UNSIGNED  NOT NULL,
    semilla                 INT UNSIGNED  NULL,
    vehiculos_disponibles   INT UNSIGNED  NOT NULL COMMENT '|V| operativo, para el indicador PUV',
    parametros              JSON          NOT NULL COMMENT 'Copia de los parámetros usados',
    creado_por              INT UNSIGNED  NULL,
    creado_en               DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    aprobado_por            INT UNSIGNED  NULL,
    aprobado_en             DATETIME      NULL,
    fecha_aprobada          DATE AS (IF(estado = 'aprobada', fecha, NULL)) STORED,
    PRIMARY KEY (id),
    UNIQUE KEY uq_programacion_aprobada (fecha_aprobada),
    KEY ix_programacion_fecha (fecha),
    CONSTRAINT fk_programacion_creador  FOREIGN KEY (creado_por)   REFERENCES usuario (id) ON DELETE SET NULL,
    CONSTRAINT fk_programacion_aprobador FOREIGN KEY (aprobado_por) REFERENCES usuario (id) ON DELETE SET NULL
) ENGINE = InnoDB;

-- x_{s,a} = 1: alternativa (vehículo, conductor, salida) elegida para cada
-- servicio. Los servicios sin cobertura (u_s = 1) quedan con estado
-- 'incidencia', sin recursos y con su motivo.
CREATE TABLE asignacion (
    id               INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    programacion_id  INT UNSIGNED      NOT NULL,
    servicio_id      INT UNSIGNED      NOT NULL,
    vehiculo_id      INT UNSIGNED      NULL,
    conductor_id     INT UNSIGNED      NULL,
    salida           SMALLINT UNSIGNED NULL,
    fin              SMALLINT UNSIGNED NULL,
    estado           ENUM('asignado', 'incidencia', 'conflicto') NOT NULL,
    motivo           VARCHAR(255)      NULL,
    ajustada         BOOLEAN           NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_asignacion_servicio (programacion_id, servicio_id),
    KEY ix_asignacion_vehiculo (vehiculo_id),
    KEY ix_asignacion_conductor (conductor_id),
    CONSTRAINT fk_asignacion_programacion FOREIGN KEY (programacion_id) REFERENCES programacion (id) ON DELETE CASCADE,
    CONSTRAINT fk_asignacion_servicio  FOREIGN KEY (servicio_id)  REFERENCES servicio (id),
    CONSTRAINT fk_asignacion_vehiculo  FOREIGN KEY (vehiculo_id)  REFERENCES vehiculo (id),
    CONSTRAINT fk_asignacion_conductor FOREIGN KEY (conductor_id) REFERENCES conductor (id),
    CONSTRAINT ck_asignacion_recursos CHECK (
        (estado = 'incidencia' AND vehiculo_id IS NULL AND conductor_id IS NULL AND salida IS NULL)
        OR (estado <> 'incidencia' AND vehiculo_id IS NOT NULL AND conductor_id IS NOT NULL
            AND salida IS NOT NULL AND fin > salida))
) ENGINE = InnoDB;

-- Curva de convergencia: mejor aptitud y aptitud promedio por generación.
CREATE TABLE historial_aptitud (
    programacion_id  INT UNSIGNED NOT NULL,
    generacion       INT UNSIGNED NOT NULL,
    mejor            DOUBLE       NOT NULL,
    promedio         DOUBLE       NOT NULL,
    PRIMARY KEY (programacion_id, generacion),
    CONSTRAINT fk_historial_programacion FOREIGN KEY (programacion_id) REFERENCES programacion (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Incidencias de la operación (HU-10): fuente de PIO, PSR y PSA.
-- ---------------------------------------------------------------------
CREATE TABLE incidencia (
    id               INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    servicio_id      INT UNSIGNED      NOT NULL,
    tipo             ENUM('retraso', 'reprogramacion', 'indisponibilidad_vehiculo', 'indisponibilidad_conductor') NOT NULL,
    fecha            DATE              NOT NULL,
    hora             SMALLINT UNSIGNED NOT NULL,
    minutos_retraso  SMALLINT UNSIGNED NULL,
    descripcion      VARCHAR(500)      NOT NULL,
    vehiculo_id      INT UNSIGNED      NULL,
    conductor_id     INT UNSIGNED      NULL,
    registrado_por   INT UNSIGNED      NULL,
    creado_en        DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY ix_incidencia_fecha_tipo (fecha, tipo),
    CONSTRAINT fk_incidencia_servicio  FOREIGN KEY (servicio_id)    REFERENCES servicio (id),
    CONSTRAINT fk_incidencia_vehiculo  FOREIGN KEY (vehiculo_id)    REFERENCES vehiculo (id),
    CONSTRAINT fk_incidencia_conductor FOREIGN KEY (conductor_id)   REFERENCES conductor (id),
    CONSTRAINT fk_incidencia_usuario   FOREIGN KEY (registrado_por) REFERENCES usuario (id) ON DELETE SET NULL,
    CONSTRAINT ck_incidencia_hora CHECK (hora < 1440),
    CONSTRAINT ck_incidencia_retraso CHECK (tipo <> 'retraso' OR minutos_retraso > 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Bitácora (sección 3.6, RNF-06)
-- ---------------------------------------------------------------------
CREATE TABLE bitacora (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    usuario_id  INT UNSIGNED    NULL,
    accion      VARCHAR(40)     NOT NULL,
    entidad     VARCHAR(40)     NOT NULL,
    entidad_id  INT UNSIGNED    NULL,
    detalle     JSON            NOT NULL,
    fecha_hora  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY ix_bitacora_fecha (fecha_hora),
    CONSTRAINT fk_bitacora_usuario FOREIGN KEY (usuario_id) REFERENCES usuario (id) ON DELETE SET NULL
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Vista para reportes y para revisar la programación en MySQL Workbench
-- ---------------------------------------------------------------------
CREATE VIEW v_asignacion_detalle AS
SELECT
    p.id                                            AS programacion_id,
    p.fecha,
    p.estado                                        AS estado_programacion,
    s.codigo                                        AS servicio,
    r.codigo                                        AS ruta,
    s.prioridad,
    a.estado                                        AS estado_asignacion,
    v.codigo                                        AS vehiculo,
    c.codigo                                        AS conductor,
    TIME_FORMAT(SEC_TO_TIME(a.salida * 60), '%H:%i') AS hora_salida,
    TIME_FORMAT(SEC_TO_TIME(a.fin * 60), '%H:%i')    AS hora_termino,
    a.motivo
FROM asignacion a
JOIN programacion p ON p.id = a.programacion_id
JOIN servicio     s ON s.id = a.servicio_id
JOIN ruta         r ON r.id = s.ruta_id
LEFT JOIN vehiculo  v ON v.id = a.vehiculo_id
LEFT JOIN conductor c ON c.id = a.conductor_id;
