/* =====================================================================
   PRY2204 - Evaluación Final Transversal (EFT) - Semana 9
   Caso: Asociación Nacional de Fútbol Profesional (ANFP)
   Usuario: PRY2204_S9  |  Motor: Oracle Database 19c XE (o superior)

   Cómo ejecutarlo: conectado como PRY2204_S9, abrir este archivo y
   usar "Ejecutar script" (F5).

   Contenido
     0) Limpieza (permite volver a ejecutar el script)
     1) Creación de tablas, secuencia y restricciones
     2) Poblamiento
     3) Informes (Fase 4)
   ===================================================================== */


/* ---------------------------------------------------------------------
   0) LIMPIEZA
   --------------------------------------------------------------------- */
BEGIN
    FOR t IN (SELECT table_name
                FROM user_tables
               WHERE table_name IN ('JUGADOR_IDIOMA', 'JUGADOR_CLUB', 'PERSONAL_PLANTA',
                                    'JUGADOR', 'TRABAJADOR', 'IDIOMA', 'ESCUELA_FUTBOL',
                                    'CLUB_FUTBOL', 'NACIONALIDAD', 'ASOCIACION',
                                    'COMUNA', 'REGION'))
    LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;

    FOR s IN (SELECT sequence_name
                FROM user_sequences
               WHERE sequence_name = 'SEQ_CLUB_FUTBOL')
    LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
    END LOOP;
END;
/


/* ---------------------------------------------------------------------
   1) CREACIÓN DE TABLAS (de las que no tienen FK hacia las que sí)
   Convención de nombres de restricciones: PK_/FK_/UN_/CK_ + tabla (+ detalle)
   --------------------------------------------------------------------- */

-- 1.1 REGION
CREATE TABLE region (
    id_region  NUMBER(2)    NOT NULL,
    nombre     VARCHAR2(60) NOT NULL,
    CONSTRAINT pk_region PRIMARY KEY (id_region)
);

-- 1.2 COMUNA
CREATE TABLE comuna (
    id_comuna  NUMBER(4)    NOT NULL,
    id_region  NUMBER(2)    NOT NULL,
    nombre     VARCHAR2(60) NOT NULL,
    CONSTRAINT pk_comuna        PRIMARY KEY (id_comuna),
    CONSTRAINT fk_comuna_region FOREIGN KEY (id_region) REFERENCES region (id_region)
);

-- 1.3 ASOCIACION (fecha de creación >= 31-12-1980; tipo P = profesional, A = amateur)
CREATE TABLE asociacion (
    id_asociacion      NUMBER(3)    NOT NULL,
    nombre_asociacion  VARCHAR2(80) NOT NULL,
    fecha_creacion     DATE         NOT NULL,
    tipo_asociacion    CHAR(1)      NOT NULL,
    CONSTRAINT pk_asociacion       PRIMARY KEY (id_asociacion),
    CONSTRAINT ck_asociacion_fecha CHECK (fecha_creacion >= DATE '1980-12-31'),
    CONSTRAINT ck_asociacion_tipo  CHECK (tipo_asociacion IN ('P', 'A'))
);

-- 1.4 NACIONALIDAD (IDENTITY: parte en 210 y aumenta de 2 en 2)
CREATE TABLE nacionalidad (
    id_nacion    NUMBER(4)    GENERATED ALWAYS AS IDENTITY (START WITH 210 INCREMENT BY 2) NOT NULL,
    descripcion  VARCHAR2(40) NOT NULL,
    CONSTRAINT pk_nacionalidad          PRIMARY KEY (id_nacion),
    CONSTRAINT un_nacionalidad_descrip  UNIQUE (descripcion)
);

-- 1.5 CLUB_FUTBOL (código por secuencia: parte en 703 y aumenta de 4 en 4; nombre único)
CREATE SEQUENCE seq_club_futbol START WITH 703 INCREMENT BY 4 NOCACHE NOCYCLE;

CREATE TABLE club_futbol (
    id_club          NUMBER(5)     NOT NULL,
    nombre_club      VARCHAR2(60)  NOT NULL,
    patrimonio       NUMBER(15)    DEFAULT 0 NOT NULL,
    ubicacion_calle  VARCHAR2(100) NOT NULL,
    tipo_club        VARCHAR2(12)  DEFAULT 'Profesional' NOT NULL,
    CONSTRAINT pk_club_futbol      PRIMARY KEY (id_club),
    CONSTRAINT un_club_futbol_nom  UNIQUE (nombre_club),
    CONSTRAINT ck_club_futbol_pat  CHECK (patrimonio >= 0),
    CONSTRAINT ck_club_futbol_tipo CHECK (tipo_club IN ('Profesional', 'Amateur'))
);

-- 1.6 ESCUELA_FUTBOL
CREATE TABLE escuela_futbol (
    id_escuela       NUMBER(5)    NOT NULL,
    nombre_escuela   VARCHAR2(80) NOT NULL,
    capacidad        NUMBER(6)    NOT NULL,
    fecha_fundacion  DATE         NOT NULL,
    CONSTRAINT pk_escuela_futbol      PRIMARY KEY (id_escuela),
    CONSTRAINT ck_escuela_futbol_cap  CHECK (capacidad > 0)
);

-- 1.7 IDIOMA
CREATE TABLE idioma (
    id_idioma      NUMBER(3)    NOT NULL,
    nombre_idioma  VARCHAR2(40) NOT NULL,
    CONSTRAINT pk_idioma     PRIMARY KEY (id_idioma),
    CONSTRAINT un_idioma_nom UNIQUE (nombre_idioma)
);

-- 1.8 TRABAJADOR (supertipo de JUGADOR y PERSONAL_PLANTA)
CREATE TABLE trabajador (
    num_inscripcion   NUMBER(9)     NOT NULL,
    rut               NUMBER(8)     NOT NULL,
    dv_rut            CHAR(1)       NOT NULL,
    nombres           VARCHAR2(60)  NOT NULL,
    apellido_paterno  VARCHAR2(40)  NOT NULL,
    apellido_materno  VARCHAR2(40),
    sueldo_base       NUMBER(10)    DEFAULT 0 NOT NULL,
    fecha_nacimiento  DATE          NOT NULL,
    genero            CHAR(1)       NOT NULL,
    estado_civil      VARCHAR2(15)  NOT NULL,
    telefono_movil    VARCHAR2(15)  NOT NULL,
    direccion         VARCHAR2(120) NOT NULL,
    id_comuna         NUMBER(4)     NOT NULL,
    id_nacion         NUMBER(4)     NOT NULL,
    CONSTRAINT pk_trabajador        PRIMARY KEY (num_inscripcion),
    CONSTRAINT un_trabajador_rut    UNIQUE (rut),
    CONSTRAINT ck_trabajador_dv     CHECK (dv_rut IN ('0','1','2','3','4','5','6','7','8','9','K')),
    CONSTRAINT ck_trabajador_sueldo CHECK (sueldo_base >= 0),
    CONSTRAINT ck_trabajador_genero CHECK (genero IN ('M', 'F')),
    CONSTRAINT ck_trabajador_ecivil CHECK (estado_civil IN ('Soltero', 'Casado', 'Divorciado', 'Viudo', 'Conviviente')),
    CONSTRAINT fk_trabajador_comuna FOREIGN KEY (id_comuna) REFERENCES comuna (id_comuna),
    CONSTRAINT fk_trabajador_nacion FOREIGN KEY (id_nacion) REFERENCES nacionalidad (id_nacion)
);

-- 1.9 JUGADOR (subtipo: PK = FK hacia TRABAJADOR)
--     id_escuela y anio_fin_amateur pueden quedar vacíos, pero siempre juntos.
CREATE TABLE jugador (
    num_inscripcion      NUMBER(9)    NOT NULL,
    puesto               VARCHAR2(20) NOT NULL,
    monto_total_premios  NUMBER(12)   DEFAULT 0 NOT NULL,
    id_asociacion        NUMBER(3)    NOT NULL,
    id_escuela           NUMBER(5),
    anio_fin_amateur     NUMBER(4),
    CONSTRAINT pk_jugador             PRIMARY KEY (num_inscripcion),
    CONSTRAINT ck_jugador_puesto      CHECK (puesto IN ('Arquero', 'Defensa', 'Mediocampista', 'Delantero')),
    CONSTRAINT ck_jugador_premios     CHECK (monto_total_premios >= 0),
    CONSTRAINT ck_jugador_escuela_anio CHECK (
                   (id_escuela IS NULL     AND anio_fin_amateur IS NULL)
                OR (id_escuela IS NOT NULL AND anio_fin_amateur IS NOT NULL)),
    CONSTRAINT fk_jugador_trabajador  FOREIGN KEY (num_inscripcion) REFERENCES trabajador (num_inscripcion),
    CONSTRAINT fk_jugador_asociacion  FOREIGN KEY (id_asociacion)   REFERENCES asociacion (id_asociacion),
    CONSTRAINT fk_jugador_escuela     FOREIGN KEY (id_escuela)      REFERENCES escuela_futbol (id_escuela)
);

-- 1.10 PERSONAL_PLANTA (subtipo: PK = FK hacia TRABAJADOR)
CREATE TABLE personal_planta (
    num_inscripcion   NUMBER(9) NOT NULL,
    id_club           NUMBER(5) NOT NULL,
    horas_trabajadas  NUMBER(4),
    valor_hora_extra  NUMBER(8),
    CONSTRAINT pk_personal_planta       PRIMARY KEY (num_inscripcion),
    CONSTRAINT ck_personal_planta_horas CHECK (horas_trabajadas >= 0),
    CONSTRAINT ck_personal_planta_valor CHECK (valor_hora_extra >= 0),
    CONSTRAINT fk_personal_planta_trab  FOREIGN KEY (num_inscripcion) REFERENCES trabajador (num_inscripcion),
    CONSTRAINT fk_personal_planta_club  FOREIGN KEY (id_club)         REFERENCES club_futbol (id_club)
);

-- 1.11 JUGADOR_CLUB (historial de clubes; PK compuesta)
CREATE TABLE jugador_club (
    num_inscripcion      NUMBER(9) NOT NULL,
    id_club              NUMBER(5) NOT NULL,
    fecha_incorporacion  DATE      NOT NULL,
    fecha_fin_contrato   DATE,
    CONSTRAINT pk_jugador_club        PRIMARY KEY (num_inscripcion, id_club, fecha_incorporacion),
    CONSTRAINT ck_jugador_club_fechas CHECK (fecha_fin_contrato IS NULL OR fecha_fin_contrato >= fecha_incorporacion),
    CONSTRAINT fk_jugador_club_jugador FOREIGN KEY (num_inscripcion) REFERENCES jugador (num_inscripcion),
    CONSTRAINT fk_jugador_club_club    FOREIGN KEY (id_club)         REFERENCES club_futbol (id_club)
);

-- Un jugador solo puede tener un contrato vigente (sin fecha de término) a la vez
CREATE UNIQUE INDEX ux_jugador_club_vigente
    ON jugador_club (CASE WHEN fecha_fin_contrato IS NULL THEN num_inscripcion END);

-- 1.12 JUGADOR_IDIOMA (idiomas y nivel de dominio; PK compuesta)
CREATE TABLE jugador_idioma (
    num_inscripcion  NUMBER(9)    NOT NULL,
    id_idioma        NUMBER(3)    NOT NULL,
    nivel_dominio    VARCHAR2(12) DEFAULT 'Basico' NOT NULL,
    CONSTRAINT pk_jugador_idioma        PRIMARY KEY (num_inscripcion, id_idioma),
    CONSTRAINT ck_jugador_idioma_nivel  CHECK (nivel_dominio IN ('Basico', 'Intermedio', 'Avanzado', 'Nativo')),
    CONSTRAINT fk_jugador_idioma_jug    FOREIGN KEY (num_inscripcion) REFERENCES jugador (num_inscripcion),
    CONSTRAINT fk_jugador_idioma_idioma FOREIGN KEY (id_idioma)       REFERENCES idioma (id_idioma)
);


/* ---------------------------------------------------------------------
   2) POBLAMIENTO (orden de dependencia)
   --------------------------------------------------------------------- */

-- 2.1 REGION
-- Las regiones 8 y 16 no venían en la tabla del enunciado, pero COMUNA las usa
-- (Concepción y Chillán). Se agregan para no romper la integridad referencial.
INSERT INTO region (id_region, nombre) VALUES (1,  'ARICA Y PARINACOTA Y TARAPACA');
INSERT INTO region (id_region, nombre) VALUES (2,  'ANTOFAGASTA');
INSERT INTO region (id_region, nombre) VALUES (3,  'ATACAMA Y COQUIMBO');
INSERT INTO region (id_region, nombre) VALUES (5,  'VALPARAISO');
INSERT INTO region (id_region, nombre) VALUES (8,  'BIOBIO');
INSERT INTO region (id_region, nombre) VALUES (13, 'METROPOLITANA');
INSERT INTO region (id_region, nombre) VALUES (16, 'ÑUBLE');

-- 2.2 COMUNA
INSERT INTO comuna (id_comuna, id_region, nombre) VALUES (101, 13, 'Santiago');
INSERT INTO comuna (id_comuna, id_region, nombre) VALUES (102, 5,  'Valparaíso');
INSERT INTO comuna (id_comuna, id_region, nombre) VALUES (103, 8,  'Concepción');
INSERT INTO comuna (id_comuna, id_region, nombre) VALUES (104, 2,  'Antofagasta');
INSERT INTO comuna (id_comuna, id_region, nombre) VALUES (105, 16, 'Chillán');

-- 2.3 ASOCIACION
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (25, 'Asociación de Fútbol de Santiago',      TO_DATE('15-05-2001', 'DD-MM-YYYY'), 'P');
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (26, 'Asociación Nacional de Fútbol Amateur', TO_DATE('10-03-1998', 'DD-MM-YYYY'), 'A');
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (27, 'Asociación de Fútbol de Valparaíso',    TO_DATE('21-07-1987', 'DD-MM-YYYY'), 'P');
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (28, 'Asociación de Fútbol de Concepción',    TO_DATE('30-11-1995', 'DD-MM-YYYY'), 'A');
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (29, 'Asociación de Fútbol de Antofagasta',   TO_DATE('25-06-2003', 'DD-MM-YYYY'), 'P');
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (30, 'Asociación de Fútbol de Temuco',        TO_DATE('12-01-2010', 'DD-MM-YYYY'), 'A');
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (31, 'Asociación de Fútbol de Rancagua',      TO_DATE('08-09-1999', 'DD-MM-YYYY'), 'P');
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (32, 'Asociación de Fútbol de Puerto Montt',  TO_DATE('20-04-2005', 'DD-MM-YYYY'), 'A');
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (33, 'Asociación de Fútbol de La Serena',     TO_DATE('14-08-2012', 'DD-MM-YYYY'), 'P');
INSERT INTO asociacion (id_asociacion, nombre_asociacion, fecha_creacion, tipo_asociacion)
VALUES (34, 'Asociación de Fútbol de Chillán',       TO_DATE('01-12-2018', 'DD-MM-YYYY'), 'A');

-- 2.4 NACIONALIDAD (id_nacion lo genera la columna IDENTITY: 210, 212, 214, 216, 218)
INSERT INTO nacionalidad (descripcion) VALUES ('Chilena');
INSERT INTO nacionalidad (descripcion) VALUES ('Argentina');
INSERT INTO nacionalidad (descripcion) VALUES ('Peruana');
INSERT INTO nacionalidad (descripcion) VALUES ('Boliviana');
INSERT INTO nacionalidad (descripcion) VALUES ('Brasileña');

-- 2.5 CLUB_FUTBOL (id_club lo entrega la secuencia: 703, 707, 711, 715, 719)
INSERT INTO club_futbol (id_club, nombre_club, patrimonio, ubicacion_calle, tipo_club)
VALUES (seq_club_futbol.NEXTVAL, 'Colo-Colo',            500000000, 'Av. Marathon 5300',               'Profesional');
INSERT INTO club_futbol (id_club, nombre_club, patrimonio, ubicacion_calle, tipo_club)
VALUES (seq_club_futbol.NEXTVAL, 'Universidad de Chile', 450000000, 'Av. El Parrón 0931',              'Profesional');
INSERT INTO club_futbol (id_club, nombre_club, patrimonio, ubicacion_calle, tipo_club)
VALUES (seq_club_futbol.NEXTVAL, 'Deportes Antofagasta', 180000000, 'Avenida Angamos 01606',           'Profesional');
INSERT INTO club_futbol (id_club, nombre_club, patrimonio, ubicacion_calle, tipo_club)
VALUES (seq_club_futbol.NEXTVAL, 'Huachipato',           220000000, 'Avenida Desiderio García 909',    'Profesional');
INSERT INTO club_futbol (id_club, nombre_club, patrimonio, ubicacion_calle, tipo_club)
VALUES (seq_club_futbol.NEXTVAL, 'Ñublense',             170000000, 'Avenida Pedro Aguirre Cerda 1003', 'Profesional');

COMMIT;

-- 2.6 Verificación del poblamiento (IDENTITY y secuencia)
SELECT * FROM nacionalidad ORDER BY id_nacion;
SELECT * FROM club_futbol  ORDER BY id_club;


/* ---------------------------------------------------------------------
   3) RECUPERACIÓN DE DATOS (Fase 4)
   --------------------------------------------------------------------- */

-- Informe 1: asociaciones profesionales (P) creadas después del año 2000,
--            de la más reciente a la más antigua
SELECT 'ID:' || id_asociacion || ' * ' || nombre_asociacion AS "ASOCIACION",
       TO_CHAR(fecha_creacion, 'DD-MM-YYYY')               AS "CREADA",
       tipo_asociacion                                     AS "TIPO"
  FROM asociacion
 WHERE tipo_asociacion = 'P'
   AND EXTRACT(YEAR FROM fecha_creacion) > 2000
 ORDER BY fecha_creacion DESC;

-- Informe 2: patrimonio de clubes en pesos y en dólares (tipo de cambio $955 por dólar)
--            nombre con la letra a, patrimonio > $200.000.000, tipo Profesional,
--            ordenado por código de club de forma descendente
SELECT id_club           AS "CLUB",
       nombre_club       AS "NOMBRE CLUB",
       patrimonio        AS "PATRIMONIO EN PESOS",
       patrimonio / 955  AS "PATRIMONIO EN DOLARES"
  FROM club_futbol
 WHERE LOWER(nombre_club) LIKE '%a%'
   AND patrimonio > 200000000
   AND tipo_club = 'Profesional'
 ORDER BY id_club DESC;