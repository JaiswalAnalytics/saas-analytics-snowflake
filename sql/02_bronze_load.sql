-- ============================================================
-- PROJECT: SaaS Analytics on Snowflake
-- AUTHOR:  Shubham Jaiswal (@JaiswalAnalytics)
-- FILE:    02_bronze_load.sql
-- DESC:    Internal Stage, Bronze tables, CSV data loading
-- ============================================================

USE WAREHOUSE SAAS_WH;
USE DATABASE SAAS_ANALYTICS;
USE SCHEMA BRONZE;

-- ============================================================
-- BLOCK 6: CREATE INTERNAL STAGE (Loading Dock)
-- ============================================================

CREATE STAGE IF NOT EXISTS RAW_FILES
  COMMENT = 'Internal stage for loading raw CSV files';

-- Verify stage created
SHOW STAGES;

-- After creating stage, upload CSV files via:
-- Snowflake UI → Data → Add Data → Load files into Stage
-- Files to upload:
--   1. WA_Fn-UseC_-Telco-Customer-Churn.csv
--   2. SaaS-Sales.csv

-- Verify files uploaded
LIST @RAW_FILES;

-- ============================================================
-- BLOCK 7A: CREATE BRONZE TABLE — TELCO CHURN
-- ============================================================
-- Note: All columns VARCHAR in Bronze (schema-on-read)
-- Never enforce types in raw layer — prevents load failures

CREATE TABLE IF NOT EXISTS BRONZE.RAW_TELCO_CHURN (
    CUSTOMERID              VARCHAR,
    GENDER                  VARCHAR,
    SENIORCITIZEN           VARCHAR,
    PARTNER                 VARCHAR,
    DEPENDENTS              VARCHAR,
    TENUREMONTHS            VARCHAR,
    PHONESERVICE            VARCHAR,
    MULTIPLELINES           VARCHAR,
    INTERNETSERVICE         VARCHAR,
    ONLINESECURITY          VARCHAR,
    ONLINEBACKUP            VARCHAR,
    DEVICEPROTECTION        VARCHAR,
    TECHSUPPORT             VARCHAR,
    STREAMINGTV             VARCHAR,
    STREAMINGMOVIES         VARCHAR,
    CONTRACT                VARCHAR,
    PAPERLESSBILLING        VARCHAR,
    PAYMENTMETHOD           VARCHAR,
    MONTHLYCHARGES          VARCHAR,
    TOTALCHARGES            VARCHAR,
    CHURN                   VARCHAR
);

-- ============================================================
-- BLOCK 7B: CREATE BRONZE TABLE — SAAS SALES
-- ============================================================

CREATE TABLE IF NOT EXISTS BRONZE.RAW_SAAS_SALES (
    ROW_ID                  VARCHAR,
    ORDER_ID                VARCHAR,
    ORDER_DATE              VARCHAR,
    DATE_KEY                VARCHAR,
    CONTACT_NAME            VARCHAR,
    COUNTRY                 VARCHAR,
    CITY                    VARCHAR,
    REGION                  VARCHAR,
    SUBREGION               VARCHAR,
    CUSTOMER                VARCHAR,
    CUSTOMER_ID             VARCHAR,
    INDUSTRY                VARCHAR,
    SEGMENT                 VARCHAR,
    PRODUCT                 VARCHAR,
    LICENSE                 VARCHAR,
    SALES                   VARCHAR,
    QUANTITY                VARCHAR,
    DISCOUNT                VARCHAR,
    PROFIT                  VARCHAR
);

-- ============================================================
-- BLOCK 7C: LOAD TELCO CHURN DATA
-- ============================================================

COPY INTO BRONZE.RAW_TELCO_CHURN
FROM @BRONZE.RAW_FILES/WA_Fn-UseC_-Telco-Customer-Churn.csv
FILE_FORMAT = (
    TYPE                            = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY    = '"'
    SKIP_HEADER                     = 1
    ERROR_ON_COLUMN_COUNT_MISMATCH  = FALSE
    EMPTY_FIELD_AS_NULL             = TRUE
)
ON_ERROR = 'CONTINUE';

-- ============================================================
-- BLOCK 7D: LOAD SAAS SALES DATA
-- ============================================================

COPY INTO BRONZE.RAW_SAAS_SALES
FROM @BRONZE.RAW_FILES/SaaS-Sales.csv
FILE_FORMAT = (
    TYPE                            = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY    = '"'
    SKIP_HEADER                     = 1
    ERROR_ON_COLUMN_COUNT_MISMATCH  = FALSE
    EMPTY_FIELD_AS_NULL             = TRUE
)
ON_ERROR = 'CONTINUE';

-- ============================================================
-- BLOCK 7E: VERIFY DATA LOADED CORRECTLY
-- ============================================================

-- Row counts (expected: 7043 + 9994)
SELECT COUNT(*) AS telco_rows  FROM BRONZE.RAW_TELCO_CHURN;
SELECT COUNT(*) AS saas_rows   FROM BRONZE.RAW_SAAS_SALES;

-- Preview first 5 rows
SELECT * FROM BRONZE.RAW_TELCO_CHURN  LIMIT 5;
SELECT * FROM BRONZE.RAW_SAAS_SALES   LIMIT 5;

-- ============================================================
-- EXPECTED OUTPUT:
-- RAW_TELCO_CHURN  → 7,043 rows
-- RAW_SAAS_SALES   → 9,994 rows
-- ============================================================
