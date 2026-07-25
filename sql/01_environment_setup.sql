-- ============================================================
-- PROJECT: SaaS Analytics on Snowflake
-- AUTHOR:  Shubham Jaiswal (@JaiswalAnalytics)
-- FILE:    01_environment_setup.sql
-- DESC:    Warehouse, Database, Schemas, Roles setup
-- ============================================================

-- ============================================================
-- BLOCK 1: CREATE VIRTUAL WAREHOUSE
-- ============================================================

CREATE WAREHOUSE IF NOT EXISTS SAAS_WH
  WITH WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Warehouse for SaaS Analytics Project';

-- ============================================================
-- BLOCK 2: CREATE DATABASE
-- ============================================================

CREATE DATABASE IF NOT EXISTS SAAS_ANALYTICS
  COMMENT = 'SaaS Customer Intelligence & Revenue Analytics';

USE DATABASE SAAS_ANALYTICS;

-- ============================================================
-- BLOCK 3: CREATE MEDALLION ARCHITECTURE SCHEMAS
-- ============================================================

-- Bronze: Raw data exactly as loaded, no changes
CREATE SCHEMA IF NOT EXISTS BRONZE
  COMMENT = 'Raw layer - data loaded as-is from source files';

-- Silver: Cleaned, validated, transformed data
CREATE SCHEMA IF NOT EXISTS SILVER
  COMMENT = 'Clean layer - standardized and validated tables';

-- Gold: Business-ready star schema for BI tools
CREATE SCHEMA IF NOT EXISTS GOLD
  COMMENT = 'Business layer - fact/dimension tables for dashboards';

-- Confirm all schemas exist
SHOW SCHEMAS IN DATABASE SAAS_ANALYTICS;

-- ============================================================
-- BLOCK 4: CREATE ROLES (Security & Access Control)
-- ============================================================

CREATE ROLE IF NOT EXISTS SAAS_ENGINEER;
CREATE ROLE IF NOT EXISTS SAAS_ANALYST;

-- Grant warehouse access
GRANT USAGE ON WAREHOUSE SAAS_WH TO ROLE SAAS_ENGINEER;
GRANT USAGE ON WAREHOUSE SAAS_WH TO ROLE SAAS_ANALYST;

-- Engineer gets full control
GRANT ALL ON DATABASE SAAS_ANALYTICS TO ROLE SAAS_ENGINEER;
GRANT ALL ON ALL SCHEMAS IN DATABASE SAAS_ANALYTICS 
    TO ROLE SAAS_ENGINEER;

-- Analyst gets read-only access
GRANT USAGE ON DATABASE SAAS_ANALYTICS TO ROLE SAAS_ANALYST;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SAAS_ANALYTICS 
    TO ROLE SAAS_ANALYST;
GRANT SELECT ON ALL TABLES IN DATABASE SAAS_ANALYTICS 
    TO ROLE SAAS_ANALYST;

-- Assign roles to your user
GRANT ROLE SAAS_ENGINEER TO USER SJ8081008272;
GRANT ROLE SAAS_ANALYST  TO USER SJ8081008272;

-- ============================================================
-- BLOCK 5: ACTIVATE & CONFIRM SETUP
-- ============================================================

USE WAREHOUSE SAAS_WH;
USE DATABASE SAAS_ANALYTICS;
USE SCHEMA BRONZE;

SELECT
    CURRENT_WAREHOUSE()  AS my_warehouse,
    CURRENT_DATABASE()   AS my_database,
    CURRENT_SCHEMA()     AS my_schema,
    CURRENT_USER()       AS my_user,
    CURRENT_ROLE()       AS my_role;

-- ============================================================
-- EXPECTED OUTPUT:
-- my_warehouse  → SAAS_WH
-- my_database   → SAAS_ANALYTICS
-- my_schema     → BRONZE
-- my_user       → SJ8081008272
-- my_role       → ACCOUNTADMIN
-- ============================================================
