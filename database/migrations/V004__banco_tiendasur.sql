-- database/migrations/V004__banco_tiendasur.sql
-- Banco de pruebas de índices del Lab 5: el escenario TiendaSur de la Actividad 3.2, a escala 1/10 (clientes)
-- y 1/20 (pedidos), con las mismas proporciones: 60 % de clientes en España, 2 % de apellidos "Gonz...",
-- 100 clientes en Lorca, 2 % de pedidos pendientes, fecha correlacionada con el orden físico y cliente al azar.
-- Datos DETERMINISTAS (ORA_HASH, sin DBMS_RANDOM): todos los alumnos obtienen las mismas filas.
--   tbs_tiendasur   BIGFILE de 256 MB que crece hasta 2 GB (en bigfile el ROWID de índice usa 4 bytes de bloque)
--   tiendasur       esquema propietario sin contraseña (NO AUTHENTICATION, como V003)
--   cliente         100 000 filas · pedido 1 000 000 filas, cargados con APPEND y ORDER BY (agrupamiento por id)
--   índices         pk_cliente, ux_cli_email, ix_cli_pais_ciudad, pk_pedido, ix_ped_cliente, ix_ped_fecha,
--                   ix_ped_importe y la clave ajena fk_ped_cliente: exactamente los de la Actividad 3.2
--   estadísticas    con histograma en pais, ciudad, estado y canal (columnas de distribución sesgada)
-- Idempotente: si el usuario TIENDASUR ya existe, no hace nada.
SET FEEDBACK ON
ALTER SESSION SET CONTAINER = FREEPDB1;
WHENEVER SQLERROR EXIT SUCCESS
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_users WHERE username = 'TIENDASUR';
  IF n > 0 THEN RAISE_APPLICATION_ERROR(-20004, 'V004 ya aplicada: el esquema TIENDASUR existe, no se hace nada'); END IF;
END;
/
WHENEVER SQLERROR EXIT SQL.SQLCODE
CREATE BIGFILE TABLESPACE tbs_tiendasur
  DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/tiendasur01.dbf' SIZE 256M AUTOEXTEND ON NEXT 64M MAXSIZE 2G;
CREATE USER tiendasur NO AUTHENTICATION DEFAULT TABLESPACE tbs_tiendasur QUOTA UNLIMITED ON tbs_tiendasur;

CREATE TABLE tiendasur.cliente (
  id_cliente  NUMBER(8)     CONSTRAINT pk_cliente PRIMARY KEY,
  dni         VARCHAR2(9)   NOT NULL,
  email       VARCHAR2(60)  NOT NULL,
  nombre      VARCHAR2(30)  NOT NULL,
  apellidos   VARCHAR2(60)  NOT NULL,
  telefono    VARCHAR2(12),
  pais        CHAR(2)       NOT NULL,
  ciudad      VARCHAR2(30)  NOT NULL,
  fecha_alta  DATE          NOT NULL
);
CREATE TABLE tiendasur.pedido (
  id_pedido     NUMBER(10)   CONSTRAINT pk_pedido PRIMARY KEY,
  id_cliente    NUMBER(8)    NOT NULL,
  fecha_pedido  TIMESTAMP(0) NOT NULL,
  estado        CHAR(1)      NOT NULL CONSTRAINT ck_ped_estado CHECK (estado IN ('P', 'E', 'C', 'D')),
  importe       NUMBER(10,2) NOT NULL,
  canal         CHAR(1)      NOT NULL CONSTRAINT ck_ped_canal CHECK (canal IN ('W', 'A', 'T')),
  codigo_postal VARCHAR2(5)  NOT NULL
);

-- Clientes: el email se guarda SIEMPRE en minúsculas (Parte F, regla 1); el DNI lleva su letra de control real
INSERT /*+ APPEND */ INTO tiendasur.cliente
SELECT n,
       LPAD(n, 8, '0') || SUBSTR('TRWAGMYFPDXBNJZSQVHLCKE', MOD(n, 23) + 1, 1),
       'cliente' || n || '@tiendasur.es',
       CASE MOD(ORA_HASH(n, 4294967295, 3), 12)
         WHEN 0 THEN 'María' WHEN 1 THEN 'José' WHEN 2 THEN 'Lucía' WHEN 3 THEN 'Antonio' WHEN 4 THEN 'Carmen'
         WHEN 5 THEN 'Manuel' WHEN 6 THEN 'Laura' WHEN 7 THEN 'Javier' WHEN 8 THEN 'Ana' WHEN 9 THEN 'David'
         WHEN 10 THEN 'Elena' ELSE 'Pablo' END,
       -- Primer apellido: González exactamente en el 2 % de los clientes (Q4b, LIKE 'Gonz%')
       CASE WHEN MOD(ORA_HASH(n, 4294967295, 4), 100) < 2 THEN 'González'
            ELSE CASE MOD(ORA_HASH(n, 4294967295, 5), 16)
                   WHEN 0 THEN 'García' WHEN 1 THEN 'Rodríguez' WHEN 2 THEN 'Fernández' WHEN 3 THEN 'López'
                   WHEN 4 THEN 'Martínez' WHEN 5 THEN 'Sánchez' WHEN 6 THEN 'Pérez' WHEN 7 THEN 'Gómez'
                   WHEN 8 THEN 'Martín' WHEN 9 THEN 'Jiménez' WHEN 10 THEN 'Ruiz' WHEN 11 THEN 'Hernández'
                   WHEN 12 THEN 'Díaz' WHEN 13 THEN 'Moreno' WHEN 14 THEN 'Muñoz' ELSE 'Navarro' END END
       || ' ' ||
       CASE MOD(ORA_HASH(n, 4294967295, 6), 12)
         WHEN 0 THEN 'Romero' WHEN 1 THEN 'Alonso' WHEN 2 THEN 'Gutiérrez' WHEN 3 THEN 'Torres'
         WHEN 4 THEN 'Domínguez' WHEN 5 THEN 'Vázquez' WHEN 6 THEN 'Ramos' WHEN 7 THEN 'Gil'
         WHEN 8 THEN 'Ramírez' WHEN 9 THEN 'Serrano' WHEN 10 THEN 'Blanco' ELSE 'Molina' END,
       '6' || LPAD(MOD(ORA_HASH(n, 4294967295, 7), 100000000), 8, '0'),
       -- 60 % en España; el resto repartido entre otros 39 países (40 en total: Parte D, skip scan)
       CASE WHEN MOD(n, 1000) = 0 OR MOD(ORA_HASH(n, 4294967295, 1), 100) < 60 THEN 'ES'
            ELSE SUBSTR('PTFRDEITGBIEBENLLUCHATPLCZSKHUROBGGRSEDKFINOEELVLTSIHRUSCAMXARBRCLCOPEUYJPCNKRIN',
                        2 * MOD(ORA_HASH(n, 4294967295, 2), 39) + 1, 2) END,
       -- Lorca: exactamente 100 clientes (0,1 %), todos en España (Q6)
       CASE WHEN MOD(n, 1000) = 0 THEN 'Lorca'
            WHEN MOD(ORA_HASH(n, 4294967295, 1), 100) < 60 THEN
                 CASE MOD(ORA_HASH(n, 4294967295, 8), 10)
                   WHEN 0 THEN 'Madrid' WHEN 1 THEN 'Barcelona' WHEN 2 THEN 'Valencia' WHEN 3 THEN 'Sevilla'
                   WHEN 4 THEN 'Murcia' WHEN 5 THEN 'Cartagena' WHEN 6 THEN 'Málaga' WHEN 7 THEN 'Bilbao'
                   WHEN 8 THEN 'Zaragoza' ELSE 'Alicante' END
            ELSE 'Capital' END,
       DATE '2020-01-01' + MOD(ORA_HASH(n, 4294967295, 9), 2000)
  FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 100000)
 ORDER BY n;
COMMIT;

-- Pedidos: id_pedido y fecha_pedido crecen juntos (tres años hasta hoy) y quedan en ese orden físico
-- (agrupamiento BUENO); id_cliente se reparte al azar (agrupamiento MALO). Los pedidos más nuevos están
-- en P (2 %) y E (5 %): "todo pedido nace en P", como en la actividad. El resto: C (~97 %) o D (~3 %).
INSERT /*+ APPEND */ INTO tiendasur.pedido
SELECT n,
       MOD(ORA_HASH(n, 4294967295, 11), 100000) + 1,
       TRUNC(SYSDATE) - 3 * 365 + (n - 1) * (3 * 365) / 1000000,
       CASE WHEN n > 980000 THEN 'P'
            WHEN n > 930000 THEN 'E'
            WHEN MOD(ORA_HASH(n, 4294967295, 12), 1000) < 30 THEN 'D'
            ELSE 'C' END,
       ROUND(5 + MOD(ORA_HASH(n, 4294967295, 13), 49500) / 100, 2),
       SUBSTR('WWWWWAAAT', MOD(ORA_HASH(n, 4294967295, 14), 9) + 1, 1),
       TO_CHAR(25000 + MOD(ORA_HASH(n, 4294967295, 15), 10000))
  FROM (SELECT ROWNUM AS n FROM (SELECT 1 FROM dual CONNECT BY LEVEL <= 1000), (SELECT 1 FROM dual CONNECT BY LEVEL <= 1000))
 ORDER BY n;
COMMIT;

CREATE UNIQUE INDEX tiendasur.ux_cli_email ON tiendasur.cliente (email);
CREATE INDEX tiendasur.ix_cli_pais_ciudad ON tiendasur.cliente (pais, ciudad);
CREATE INDEX tiendasur.ix_ped_cliente ON tiendasur.pedido (id_cliente);
CREATE INDEX tiendasur.ix_ped_fecha ON tiendasur.pedido (fecha_pedido);
CREATE INDEX tiendasur.ix_ped_importe ON tiendasur.pedido (importe);
ALTER TABLE tiendasur.pedido ADD CONSTRAINT fk_ped_cliente FOREIGN KEY (id_cliente) REFERENCES tiendasur.cliente (id_cliente);

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS('TIENDASUR', 'CLIENTE', cascade => TRUE,
    method_opt => 'FOR ALL COLUMNS SIZE 1 FOR COLUMNS SIZE 254 pais, ciudad');
  DBMS_STATS.GATHER_TABLE_STATS('TIENDASUR', 'PEDIDO', cascade => TRUE,
    method_opt => 'FOR ALL COLUMNS SIZE 1 FOR COLUMNS SIZE 254 estado, canal');
END;
/
SET LINESIZE 150 PAGESIZE 50
COLUMN table_name FORMAT A8
COLUMN index_name FORMAT A20
SELECT table_name, num_rows, blocks FROM dba_tables WHERE owner = 'TIENDASUR' ORDER BY table_name;
SELECT table_name, index_name, uniqueness FROM dba_indexes WHERE owner = 'TIENDASUR' ORDER BY table_name, index_name;
EXIT
