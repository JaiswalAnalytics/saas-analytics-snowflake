-- ============================================================
-- PROJECT: SaaS Analytics on Snowflake
-- AUTHOR:  Shubham Jaiswal (@JaiswalAnalytics)
-- FILE:    04_gold_schema.sql
-- DESC:    Star Schema — Dimension & Fact tables (Gold Layer)
-- ============================================================

USE WAREHOUSE SAAS_WH;
USE DATABASE SAAS_ANALYTICS;

-- ============================================================
-- BLOCK 10A: DIMENSION TABLE — DIM_CUSTOMER
-- ============================================================

CREATE OR REPLACE TABLE GOLD.DIM_CUSTOMER AS
SELECT
    CONCAT('CUST-', customer_id)                AS customer_key,
    customer_id,
    gender,
    is_senior_citizen,
    has_partner,
    has_dependents,
    contract_type,
    payment_method,
    paperless_billing,
    internet_service,
    has_phone_service,
    multiple_lines,
    online_security,
    online_backup,
    device_protection,
    tech_support,
    streaming_tv,
    streaming_movies,
    tenure_segment,
    customer_value_segment,
    CURRENT_TIMESTAMP()                         AS gold_loaded_at
FROM SILVER.CLEAN_TELCO_CHURN
WHERE record_quality = 'VALID';

-- ============================================================
-- BLOCK 10B: DIMENSION TABLE — DIM_PRODUCT
-- ============================================================

DROP TABLE IF EXISTS GOLD.DIM_PRODUCT;

CREATE TABLE GOLD.DIM_PRODUCT AS
SELECT DISTINCT
    CONCAT('PROD-',
        UPPER(REPLACE(product_name,' ','_')))   AS product_key,
    product_name,
    product_tier,
    product_category,
    CURRENT_TIMESTAMP()                         AS gold_loaded_at
FROM SILVER.CLEAN_SAAS_SALES;

-- ============================================================
-- BLOCK 10C: DIMENSION TABLE — DIM_GEOGRAPHY
-- ============================================================

CREATE OR REPLACE TABLE GOLD.DIM_GEOGRAPHY AS
WITH unique_locations AS (
    SELECT DISTINCT
        country,
        region,
        subregion,
        city
    FROM SILVER.CLEAN_SAAS_SALES
)
SELECT
    CONCAT('GEO-',
        UPPER(REPLACE(country,' ','_')),
        '-',
        UPPER(REPLACE(city,' ','_')))           AS geography_key,
    country,
    region,
    subregion,
    city,
    CURRENT_TIMESTAMP()                         AS gold_loaded_at
FROM unique_locations;

-- ============================================================
-- BLOCK 10D: DIMENSION TABLE — DIM_DATE
-- ============================================================

CREATE OR REPLACE TABLE GOLD.DIM_DATE AS
SELECT DISTINCT
    order_date                                  AS date_id,
    order_year                                  AS year,
    order_quarter                               AS quarter,
    order_month                                 AS month_number,
    order_month_name                            AS month_name,
    DAYOFWEEK(order_date)                       AS day_of_week,
    DAYNAME(order_date)                         AS day_name,
    CASE
        WHEN DAYOFWEEK(order_date) IN (1,7)
        THEN 'Weekend'
        ELSE 'Weekday'
    END                                         AS day_type,
    CONCAT('Q', order_quarter,
           '-', order_year)                     AS quarter_label,
    CURRENT_TIMESTAMP()                         AS gold_loaded_at
FROM SILVER.CLEAN_SAAS_SALES
ORDER BY order_date;

-- ============================================================
-- BLOCK 10E: FACT TABLE — FACT_REVENUE
-- ============================================================

CREATE OR REPLACE TABLE GOLD.FACT_REVENUE AS
SELECT
    UUID_STRING()                               AS revenue_key,
    p.product_key,
    g.geography_key,
    d.date_id,
    s.order_id,
    s.customer_id,
    s.customer_name,
    s.segment,
    s.industry,
    s.contact_name,
    s.sales_amount,
    s.quantity,
    s.discount_rate,
    s.profit_amount,
    s.profit_margin_pct,
    s.product_tier,
    s.revenue_tier,
    s.record_flag,
    CURRENT_TIMESTAMP()                         AS gold_loaded_at
FROM SILVER.CLEAN_SAAS_SALES s
LEFT JOIN GOLD.DIM_PRODUCT   p
       ON s.product_name  = p.product_name
LEFT JOIN GOLD.DIM_GEOGRAPHY g
       ON s.country       = g.country
      AND s.city          = g.city
      AND s.region        = g.region
LEFT JOIN GOLD.DIM_DATE      d
       ON s.order_date    = d.date_id;

-- ============================================================
-- BLOCK 10F: FACT TABLE — FACT_CHURN
-- ============================================================

CREATE OR REPLACE TABLE GOLD.FACT_CHURN AS
SELECT
    UUID_STRING()                               AS churn_key,
    c.customer_key,
    t.customer_id,
    t.tenure_months,
    t.monthly_charges,
    t.total_charges,
    t.churn_flag,
    t.is_churned,
    ROUND(t.monthly_charges * 12, 2)            AS annual_revenue,
    CASE
        WHEN t.is_churned = 1
        THEN ROUND(t.monthly_charges * 12, 2)
        ELSE 0
    END                                         AS lost_annual_revenue,
    CASE
        WHEN t.is_churned = 0
        THEN ROUND(t.monthly_charges * t.tenure_months, 2)
        ELSE ROUND(t.total_charges, 2)
    END                                         AS customer_ltv,
    CASE
        WHEN t.contract_type = 'Month-to-month'
         AND t.tenure_months <= 12
         AND t.monthly_charges > 65             THEN 'High Risk'
        WHEN t.contract_type = 'Month-to-month'
         AND t.tenure_months <= 24              THEN 'Medium Risk'
        ELSE 'Low Risk'
    END                                         AS churn_risk_segment,
    CURRENT_TIMESTAMP()                         AS gold_loaded_at
FROM SILVER.CLEAN_TELCO_CHURN t
LEFT JOIN GOLD.DIM_CUSTOMER c
       ON t.customer_id = c.customer_id;

-- ============================================================
-- BLOCK 10G: VERIFY GOLD LAYER
-- ============================================================

-- All table row counts
SELECT 'DIM_CUSTOMER'   AS table_name, COUNT(*) AS row_count
FROM GOLD.DIM_CUSTOMER
UNION ALL
SELECT 'DIM_PRODUCT',   COUNT(*) FROM GOLD.DIM_PRODUCT
UNION ALL
SELECT 'DIM_GEOGRAPHY', COUNT(*) FROM GOLD.DIM_GEOGRAPHY
UNION ALL
SELECT 'DIM_DATE',      COUNT(*) FROM GOLD.DIM_DATE
UNION ALL
SELECT 'FACT_REVENUE',  COUNT(*) FROM GOLD.FACT_REVENUE
UNION ALL
SELECT 'FACT_CHURN',    COUNT(*) FROM GOLD.FACT_CHURN;

-- Business validation
SELECT
    COUNT(DISTINCT order_id)                    AS total_orders,
    COUNT(DISTINCT customer_id)                 AS unique_customers,
    ROUND(SUM(sales_amount), 2)                 AS total_revenue,
    ROUND(SUM(profit_amount), 2)                AS total_profit,
    ROUND(AVG(profit_margin_pct), 2)            AS avg_profit_margin,
    ROUND(SUM(sales_amount) /
          COUNT(DISTINCT order_id), 2)          AS avg_order_value
FROM GOLD.FACT_REVENUE;

-- Churn risk distribution
SELECT
    churn_risk_segment,
    COUNT(*)                                    AS customer_count,
    ROUND(AVG(monthly_charges), 2)              AS avg_monthly_charges,
    ROUND(SUM(lost_annual_revenue), 2)          AS revenue_at_risk
FROM GOLD.FACT_CHURN
GROUP BY churn_risk_segment
ORDER BY revenue_at_risk DESC;

-- ============================================================
-- EXPECTED OUTPUT:
-- DIM_CUSTOMER   → 7,043 rows
-- DIM_PRODUCT    → 14 rows
-- DIM_GEOGRAPHY  → 262 rows
-- DIM_DATE       → 1,237 rows
-- FACT_REVENUE   → 9,994 rows
-- FACT_CHURN     → 7,043 rows
-- Total Revenue  → $2,297,201.07
-- Total Profit   → $286,397.79
-- ============================================================
