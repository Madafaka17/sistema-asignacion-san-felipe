-- Esquema mínimo de la base de datos de pruebas (MySQL 8.0).
-- Subconjunto del modelo de datos de la Figura 4 de la tesis: turno, rutas, unidades,
-- conductores y autorizaciones, servicios con su lugar en la cola, alternativas
-- admisibles, corridas y programaciones. Se aplica solo sobre bases efímeras con
-- prefijo sf_test_ (lo verifica persistencia.config antes de crear la base).
-- Las restricciones CHECK impiden cargar datos que no sean sintéticos y registrar
-- corridas que no sean de la prueba de humo.

CREATE TABLE turno (
  id_turno            SMALLINT UNSIGNED NOT NULL,
  origen_datos        VARCHAR(12)   NOT NULL,
  semilla_generador   INT UNSIGNED  NOT NULL,
  duracion_min        DECIMAL(8,2)  NOT NULL,
  t_min               DECIMAL(8,2)  NOT NULL,
  b_retraso           DECIMAL(10,2) NOT NULL,
  b_reprogramacion    DECIMAL(10,2) NOT NULL,
  b_tiempo_muerto     DECIMAL(10,2) NOT NULL,
  b_desequilibrio     DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id_turno),
  CONSTRAINT ck_turno_sintetico CHECK (origen_datos = 'sintetico')
) ENGINE=InnoDB;

CREATE TABLE ruta (
  id_ruta   CHAR(3)      NOT NULL,
  nombre    VARCHAR(40)  NOT NULL,
  ida_min   DECIMAL(8,2) NOT NULL,
  PRIMARY KEY (id_ruta)
) ENGINE=InnoDB;

CREATE TABLE conductor (
  id_conductor           VARCHAR(8)        NOT NULL,
  id_turno               SMALLINT UNSIGNED NOT NULL,
  conduccion_previa_min  DECIMAL(8,2)      NOT NULL,
  limite_conduccion_min  DECIMAL(8,2)      NOT NULL,
  PRIMARY KEY (id_conductor),
  CONSTRAINT fk_conductor_turno FOREIGN KEY (id_turno) REFERENCES turno (id_turno)
) ENGINE=InnoDB;

CREATE TABLE unidad (
  id_unidad           VARCHAR(8)        NOT NULL,
  id_turno            SMALLINT UNSIGNED NOT NULL,
  asientos            TINYINT UNSIGNED  NOT NULL,
  conductor_habitual  VARCHAR(8)        NULL,
  PRIMARY KEY (id_unidad),
  CONSTRAINT fk_unidad_turno FOREIGN KEY (id_turno) REFERENCES turno (id_turno),
  CONSTRAINT fk_unidad_habitual FOREIGN KEY (conductor_habitual) REFERENCES conductor (id_conductor)
) ENGINE=InnoDB;

CREATE TABLE autorizacion (
  id_unidad     VARCHAR(8) NOT NULL,
  id_conductor  VARCHAR(8) NOT NULL,
  tipo          ENUM('habitual', 'plantilla', 'reemplazo') NOT NULL,
  PRIMARY KEY (id_unidad, id_conductor),
  CONSTRAINT fk_autorizacion_unidad FOREIGN KEY (id_unidad) REFERENCES unidad (id_unidad),
  CONSTRAINT fk_autorizacion_conductor FOREIGN KEY (id_conductor) REFERENCES conductor (id_conductor)
) ENGINE=InnoDB;

CREATE TABLE servicio (
  id_servicio               VARCHAR(8)        NOT NULL,
  id_turno                  SMALLINT UNSIGNED NOT NULL,
  orden                     SMALLINT UNSIGNED NOT NULL,
  id_ruta                   CHAR(3)           NOT NULL,
  unidad_en_cola            VARCHAR(8)        NOT NULL,
  salida_nominal_min        DECIMAL(8,2)      NOT NULL,
  prioridad                 TINYINT UNSIGNED  NOT NULL,
  alternativa_comprometida  SMALLINT UNSIGNED NULL,
  PRIMARY KEY (id_servicio),
  UNIQUE KEY uq_servicio_orden (id_turno, orden),
  CONSTRAINT fk_servicio_turno FOREIGN KEY (id_turno) REFERENCES turno (id_turno),
  CONSTRAINT fk_servicio_ruta FOREIGN KEY (id_ruta) REFERENCES ruta (id_ruta),
  CONSTRAINT fk_servicio_cola FOREIGN KEY (unidad_en_cola) REFERENCES unidad (id_unidad),
  CONSTRAINT ck_servicio_prioridad CHECK (prioridad BETWEEN 1 AND 3)
) ENGINE=InnoDB;

-- Cada alternativa usa un par (unidad, conductor) autorizado: la clave foránea compuesta
-- hace cumplir en la base la regla de conductores habituales y reemplazos autorizados.
CREATE TABLE alternativa (
  id_servicio    VARCHAR(8)        NOT NULL,
  indice         SMALLINT UNSIGNED NOT NULL,
  id_unidad      VARCHAR(8)        NOT NULL,
  id_conductor   VARCHAR(8)        NOT NULL,
  codigo_salida  VARCHAR(4)        NOT NULL,
  inicio_min     DECIMAL(8,2)      NOT NULL,
  duracion_min   DECIMAL(8,2)      NOT NULL,
  PRIMARY KEY (id_servicio, indice),
  CONSTRAINT fk_alternativa_servicio FOREIGN KEY (id_servicio) REFERENCES servicio (id_servicio),
  CONSTRAINT fk_alternativa_par FOREIGN KEY (id_unidad, id_conductor)
    REFERENCES autorizacion (id_unidad, id_conductor)
) ENGINE=InnoDB;

CREATE TABLE corrida (
  id_corrida      INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  id_turno        SMALLINT UNSIGNED NOT NULL,
  tipo            VARCHAR(12)       NOT NULL,
  semilla_ag      INT UNSIGNED      NOT NULL,
  aptitud         DOUBLE            NOT NULL,
  phi             INT UNSIGNED      NOT NULL,
  validador       INT UNSIGNED      NOT NULL,
  huella_salida   CHAR(64)          NOT NULL,
  registrada_utc  DATETIME(3)       NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  PRIMARY KEY (id_corrida),
  CONSTRAINT fk_corrida_turno FOREIGN KEY (id_turno) REFERENCES turno (id_turno),
  CONSTRAINT ck_corrida_humo CHECK (tipo = 'humo')
) ENGINE=InnoDB;

CREATE TABLE programacion (
  id_corrida          INT UNSIGNED      NOT NULL,
  id_servicio         VARCHAR(8)        NOT NULL,
  indice_alternativa  SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (id_corrida, id_servicio),
  CONSTRAINT fk_programacion_corrida FOREIGN KEY (id_corrida) REFERENCES corrida (id_corrida),
  CONSTRAINT fk_programacion_alternativa FOREIGN KEY (id_servicio, indice_alternativa)
    REFERENCES alternativa (id_servicio, indice)
) ENGINE=InnoDB;
