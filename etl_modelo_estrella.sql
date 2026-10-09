-- =====================================================================
-- Pre-entrega 1 - ETL y Modelo Estrella - Churn Telco (IBM 11.1.3+)
-- Motor: MySQL 8.0
-- Fuente: https://www.kaggle.com/datasets/ylchang/telco-customer-churn-1113
-- Antes de ejecutar: habilitar local_infile y ajustar las rutas de los CSV.
--   SET GLOBAL local_infile = 1;
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Creación de las dos bases de datos de origen y la base destino
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS db_clientes;
DROP DATABASE IF EXISTS db_operaciones;
DROP DATABASE IF EXISTS db_churn;
CREATE DATABASE db_clientes;     -- Fuente 1: CRM / maestro de clientes
CREATE DATABASE db_operaciones;  -- Fuente 2: facturación y gestión comercial
CREATE DATABASE db_churn;        -- Destino: base consolidada + modelo estrella

-- ---------------------------------------------------------------------
-- 1. EXTRACCIÓN - Fuente 1: db_clientes
-- ---------------------------------------------------------------------
CREATE TABLE db_clientes.demographics (
    customer_id          VARCHAR(20) PRIMARY KEY,
    count_               INT,
    gender               VARCHAR(10),
    age                  INT,
    under_30             VARCHAR(3),
    senior_citizen       VARCHAR(3),
    married              VARCHAR(3),
    dependents           VARCHAR(3),
    number_of_dependents INT
);

CREATE TABLE db_clientes.location (
    customer_id VARCHAR(20) PRIMARY KEY,
    count_      INT,
    country     VARCHAR(50),
    state       VARCHAR(50),
    city        VARCHAR(80),
    zip_code    VARCHAR(10),
    lat_long    VARCHAR(50),
    latitude    DECIMAL(9,6),
    longitude   DECIMAL(9,6)
);

CREATE TABLE db_clientes.population (
    id         INT,
    zip_code   VARCHAR(10) PRIMARY KEY,
    population INT
);

LOAD DATA LOCAL INFILE 'C:/datos/Telco_customer_churn_demographics.csv'
INTO TABLE db_clientes.demographics
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/datos/Telco_customer_churn_location.csv'
INTO TABLE db_clientes.location
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/datos/Telco_customer_churn_population.csv'
INTO TABLE db_clientes.population
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- ---------------------------------------------------------------------
-- 1. EXTRACCIÓN - Fuente 2: db_operaciones
-- ---------------------------------------------------------------------
CREATE TABLE db_operaciones.services (
    customer_id                       VARCHAR(20) PRIMARY KEY,
    count_                            INT,
    quarter                           VARCHAR(5),
    referred_a_friend                 VARCHAR(3),
    number_of_referrals               INT,
    tenure_in_months                  INT,
    offer                             VARCHAR(20),
    phone_service                     VARCHAR(3),
    avg_monthly_long_distance_charges DECIMAL(10,2),
    multiple_lines                    VARCHAR(3),
    internet_service                  VARCHAR(3),
    internet_type                     VARCHAR(20),
    avg_monthly_gb_download           INT,
    online_security                   VARCHAR(3),
    online_backup                     VARCHAR(3),
    device_protection_plan            VARCHAR(3),
    premium_tech_support              VARCHAR(3),
    streaming_tv                      VARCHAR(3),
    streaming_movies                  VARCHAR(3),
    streaming_music                   VARCHAR(3),
    unlimited_data                    VARCHAR(3),
    contract                          VARCHAR(20),
    paperless_billing                 VARCHAR(3),
    payment_method                    VARCHAR(30),
    monthly_charge                    DECIMAL(10,2),
    total_charges                     DECIMAL(10,2),
    total_refunds                     DECIMAL(10,2),
    total_extra_data_charges          DECIMAL(10,2),
    total_long_distance_charges       DECIMAL(10,2),
    total_revenue                     DECIMAL(10,2)
);

CREATE TABLE db_operaciones.status (
    customer_id        VARCHAR(20) PRIMARY KEY,
    count_             INT,
    quarter            VARCHAR(5),
    satisfaction_score INT,
    customer_status    VARCHAR(10),
    churn_label        VARCHAR(3),
    churn_value        TINYINT,
    churn_score        INT,
    cltv               INT,
    churn_category     VARCHAR(30),
    churn_reason       VARCHAR(100)
);

LOAD DATA LOCAL INFILE 'C:/datos/Telco_customer_churn_services.csv'
INTO TABLE db_operaciones.services
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/datos/Telco_customer_churn_status.csv'
INTO TABLE db_operaciones.status
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- Verificación de la carga (se esperan 7.043 filas por tabla de clientes)
SELECT 'demographics' AS tabla, COUNT(*) FROM db_clientes.demographics
UNION ALL SELECT 'location',  COUNT(*) FROM db_clientes.location
UNION ALL SELECT 'population',COUNT(*) FROM db_clientes.population
UNION ALL SELECT 'services',  COUNT(*) FROM db_operaciones.services
UNION ALL SELECT 'status',    COUNT(*) FROM db_operaciones.status;

-- ---------------------------------------------------------------------
-- 2. CONSOLIDACIÓN: JOIN entre las dos bases + filtro de muestra
--    (se excluyen clientes 'Joined' y columnas constantes)
-- ---------------------------------------------------------------------
CREATE TABLE db_churn.clientes_consolidado AS
SELECT
    d.customer_id,
    d.gender, d.age, d.senior_citizen, d.married, d.dependents,
    d.number_of_dependents,
    l.city, l.zip_code, l.latitude, l.longitude,
    p.population,
    s.referred_a_friend, s.number_of_referrals, s.tenure_in_months, s.offer,
    s.phone_service, s.avg_monthly_long_distance_charges, s.multiple_lines,
    s.internet_service, s.internet_type, s.avg_monthly_gb_download,
    s.online_security, s.online_backup, s.device_protection_plan,
    s.premium_tech_support, s.streaming_tv, s.streaming_movies,
    s.streaming_music, s.unlimited_data,
    s.contract, s.paperless_billing, s.payment_method,
    s.monthly_charge, s.total_charges, s.total_refunds,
    s.total_extra_data_charges, s.total_long_distance_charges, s.total_revenue,
    st.satisfaction_score, st.customer_status, st.churn_value, st.churn_score,
    st.cltv, st.churn_category, st.churn_reason
FROM db_clientes.demographics d
JOIN db_clientes.location        l  ON l.customer_id  = d.customer_id
LEFT JOIN db_clientes.population p  ON p.zip_code     = l.zip_code
JOIN db_operaciones.services     s  ON s.customer_id  = d.customer_id
JOIN db_operaciones.status       st ON st.customer_id = d.customer_id
WHERE st.customer_status <> 'Joined';

-- Se esperan 6.589 filas (4.720 Stayed + 1.869 Churned)
SELECT customer_status, COUNT(*) FROM db_churn.clientes_consolidado
GROUP BY customer_status;

-- ---------------------------------------------------------------------
-- 3. MODELO ESTRELLA
-- ---------------------------------------------------------------------
USE db_churn;

CREATE TABLE dim_cliente (
    sk_cliente           INT AUTO_INCREMENT PRIMARY KEY,
    customer_id          VARCHAR(20) UNIQUE,
    gender               VARCHAR(10),
    age                  INT,
    senior_citizen       VARCHAR(3),
    married              VARCHAR(3),
    dependents           VARCHAR(3),
    number_of_dependents INT
);

CREATE TABLE dim_ubicacion (
    sk_ubicacion INT AUTO_INCREMENT PRIMARY KEY,
    zip_code     VARCHAR(10) UNIQUE,
    city         VARCHAR(80),
    latitude     DECIMAL(9,6),
    longitude    DECIMAL(9,6),
    population   INT
);

CREATE TABLE dim_contrato (
    sk_contrato       INT AUTO_INCREMENT PRIMARY KEY,
    contract          VARCHAR(20),
    payment_method    VARCHAR(30),
    paperless_billing VARCHAR(3),
    offer             VARCHAR(20)
);

CREATE TABLE dim_servicios (
    sk_servicios           INT AUTO_INCREMENT PRIMARY KEY,
    phone_service          VARCHAR(3),
    multiple_lines         VARCHAR(3),
    internet_service       VARCHAR(3),
    internet_type          VARCHAR(20),
    online_security        VARCHAR(3),
    online_backup          VARCHAR(3),
    device_protection_plan VARCHAR(3),
    premium_tech_support   VARCHAR(3),
    streaming_tv           VARCHAR(3),
    streaming_movies       VARCHAR(3),
    streaming_music        VARCHAR(3),
    unlimited_data         VARCHAR(3)
);

CREATE TABLE fact_churn (
    sk_cliente                  INT,
    sk_ubicacion                INT,
    sk_contrato                 INT,
    sk_servicios                INT,
    tenure_in_months            INT,
    number_of_referrals         INT,
    monthly_charge              DECIMAL(10,2),
    total_charges               DECIMAL(10,2),
    total_refunds               DECIMAL(10,2),
    total_extra_data_charges    DECIMAL(10,2),
    total_long_distance_charges DECIMAL(10,2),
    total_revenue               DECIMAL(10,2),
    avg_monthly_gb_download     INT,
    satisfaction_score          INT,
    cltv                        INT,
    churn_value                 TINYINT,
    PRIMARY KEY (sk_cliente),
    FOREIGN KEY (sk_cliente)   REFERENCES dim_cliente(sk_cliente),
    FOREIGN KEY (sk_ubicacion) REFERENCES dim_ubicacion(sk_ubicacion),
    FOREIGN KEY (sk_contrato)  REFERENCES dim_contrato(sk_contrato),
    FOREIGN KEY (sk_servicios) REFERENCES dim_servicios(sk_servicios)
);

-- Poblar dimensiones
INSERT INTO dim_cliente (customer_id, gender, age, senior_citizen, married,
                         dependents, number_of_dependents)
SELECT customer_id, gender, age, senior_citizen, married, dependents,
       number_of_dependents
FROM clientes_consolidado;

INSERT INTO dim_ubicacion (zip_code, city, latitude, longitude, population)
SELECT zip_code, MIN(city), MIN(latitude), MIN(longitude), MIN(population)
FROM clientes_consolidado
GROUP BY zip_code;

INSERT INTO dim_contrato (contract, payment_method, paperless_billing, offer)
SELECT DISTINCT contract, payment_method, paperless_billing, offer
FROM clientes_consolidado;

INSERT INTO dim_servicios (phone_service, multiple_lines, internet_service,
    internet_type, online_security, online_backup, device_protection_plan,
    premium_tech_support, streaming_tv, streaming_movies, streaming_music,
    unlimited_data)
SELECT DISTINCT phone_service, multiple_lines, internet_service,
    internet_type, online_security, online_backup, device_protection_plan,
    premium_tech_support, streaming_tv, streaming_movies, streaming_music,
    unlimited_data
FROM clientes_consolidado;

-- Poblar tabla de hechos (<=> compara NULL con NULL de forma segura)
INSERT INTO fact_churn
SELECT dc.sk_cliente, du.sk_ubicacion, dco.sk_contrato, ds.sk_servicios,
       c.tenure_in_months, c.number_of_referrals, c.monthly_charge,
       c.total_charges, c.total_refunds, c.total_extra_data_charges,
       c.total_long_distance_charges, c.total_revenue,
       c.avg_monthly_gb_download, c.satisfaction_score, c.cltv, c.churn_value
FROM clientes_consolidado c
JOIN dim_cliente   dc  ON dc.customer_id = c.customer_id
JOIN dim_ubicacion du  ON du.zip_code    = c.zip_code
JOIN dim_contrato  dco ON dco.contract          <=> c.contract
                      AND dco.payment_method    <=> c.payment_method
                      AND dco.paperless_billing <=> c.paperless_billing
                      AND dco.offer             <=> c.offer
JOIN dim_servicios ds  ON ds.phone_service          <=> c.phone_service
                      AND ds.multiple_lines         <=> c.multiple_lines
                      AND ds.internet_service       <=> c.internet_service
                      AND ds.internet_type          <=> c.internet_type
                      AND ds.online_security        <=> c.online_security
                      AND ds.online_backup          <=> c.online_backup
                      AND ds.device_protection_plan <=> c.device_protection_plan
                      AND ds.premium_tech_support   <=> c.premium_tech_support
                      AND ds.streaming_tv           <=> c.streaming_tv
                      AND ds.streaming_movies       <=> c.streaming_movies
                      AND ds.streaming_music        <=> c.streaming_music
                      AND ds.unlimited_data         <=> c.unlimited_data;

-- ---------------------------------------------------------------------
-- 4. Consultas de validación / análisis sobre el modelo estrella
-- ---------------------------------------------------------------------
-- 4.1 Debe coincidir con clientes_consolidado (6.589)
SELECT COUNT(*) AS filas_hechos FROM fact_churn;

-- 4.2 Tasa de churn por tipo de contrato
SELECT dco.contract,
       COUNT(*)                         AS clientes,
       SUM(f.churn_value)               AS fugados,
       ROUND(100 * AVG(f.churn_value),1) AS tasa_churn_pct
FROM fact_churn f
JOIN dim_contrato dco ON dco.sk_contrato = f.sk_contrato
GROUP BY dco.contract
ORDER BY tasa_churn_pct DESC;

-- 4.3 Tasa de churn por tipo de Internet
SELECT ds.internet_type,
       COUNT(*) AS clientes,
       ROUND(100 * AVG(f.churn_value),1) AS tasa_churn_pct
FROM fact_churn f
JOIN dim_servicios ds ON ds.sk_servicios = f.sk_servicios
GROUP BY ds.internet_type
ORDER BY tasa_churn_pct DESC;

-- 4.4 Top 10 ciudades con más clientes fugados
SELECT du.city, SUM(f.churn_value) AS fugados, COUNT(*) AS clientes
FROM fact_churn f
JOIN dim_ubicacion du ON du.sk_ubicacion = f.sk_ubicacion
GROUP BY du.city
ORDER BY fugados DESC
LIMIT 10;
