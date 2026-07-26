-- ============================================================
-- PROJECT: SaaS Analytics on Snowflake
-- AUTHOR:  Shubham Jaiswal (@JaiswalAnalytics)
-- FILE:    03_silver_transform.sql
-- DESC:    Data cleaning, type casting, derived columns
-- ============================================================

USE WAREHOUSE SAAS_WH;
USE DATABASE SAAS_ANALYTICS;

-- ============================================================
-- BLOCK 8A: DATA EXPLORATION — TELCO CHURN
-- ============================================================

-- Check for NULL values
SELECT
    COUNT(*)                                        AS total_rows,
    COUNT(CASE WHEN CUSTOMERID IS NULL
               THEN 1 END)                          AS null_customerids,
    COUNT(CASE WHEN MONTHLYCHARGES IS NULL
               THEN 1 END)                          AS null_monthly_charges,
    COUNT(CASE WHEN TOTALCHARGES IS NULL
               THEN 1 END)                          AS null_total_charges,
    COUNT(CASE WHEN CHURN IS NULL
               THEN 1 END)                          AS null_churn,
    COUNT(CASE WHEN TENUREMONTHS IS NULL
               THEN 1 END)                          AS null_tenure
FROM BRONZE.RAW_TELCO_CHURN;

-- Check for duplicates
SELECT
    CUSTOMERID,
    COUNT(*)                                        AS appearance_count
FROM BRONZE.RAW_TELCO_CHURN
GROUP BY CUSTOMERID
HAVING COUNT(*) > 1;

-- Check distinct values
SELECT DISTINCT CONTRACT        FROM BRONZE.RAW_TELCO_CHURN;
SELECT DISTINCT INTERNETSERVICE FROM BRONZE.RAW_TELCO_CHURN;
SELECT DISTINCT CHURN           FROM BRONZE.RAW_TELCO_CHURN;

-- Check TotalCharges data quality
SELECT
    TOTALCHARGES,
    COUNT(*)                                        AS row_count
FROM BRONZE.RAW_TELCO_CHURN
WHERE TRY_TO_NUMBER(TOTALCHARGES) IS NULL
GROUP BY TOTALCHARGES;

-- ============================================================
-- BLOCK 8B: DATA EXPLORATION — SAAS SALES
-- ============================================================

-- Check for NULLs
SELECT
    COUNT(*)                                        AS total_rows,
    COUNT(CASE WHEN ORDER_ID IS NULL
               THEN 1 END)                          AS null_order_ids,
    COUNT(CASE WHEN SALES IS NULL
               THEN 1 END)                          AS null_sales,
    COUNT(CASE WHEN PROFIT IS NULL
               THEN 1 END)                          AS null_profit
FROM BRONZE.RAW_SAAS_SALES;

-- Check date format
SELECT DISTINCT
    ORDER_DATE,
    LENGTH(ORDER_DATE)                              AS date_length
FROM BRONZE.RAW_SAAS_SALES
LIMIT 10;

-- Check sales & profit ranges
SELECT
    MIN(TRY_TO_NUMBER(SALES))                       AS min_sales,
    MAX(TRY_TO_NUMBER(SALES))                       AS max_sales,
    AVG(TRY_TO_NUMBER(SALES))                       AS avg_sales,
    MIN(TRY_TO_NUMBER(PROFIT))                      AS min_profit,
    MAX(TRY_TO_NUMBER(PROFIT))                      AS max_profit,
    AVG(TRY_TO_NUMBER(PROFIT))                      AS avg_profit
FROM BRONZE.RAW_SAAS_SALES;

-- ============================================================
-- BLOCK 9A: SILVER TABLE — TELCO CHURN (CLEANED)
-- ============================================================

CREATE OR REPLACE TABLE SILVER.CLEAN_TELCO_CHURN AS
SELECT
    -- CUSTOMER IDENTITY
    CUSTOMERID                                      AS customer_id,

    -- DEMOGRAPHICS
    UPPER(TRIM(GENDER))                             AS gender,
    CASE
        WHEN SENIORCITIZEN = '1' THEN 'Yes'
        WHEN SENIORCITIZEN = '0' THEN 'No'
        ELSE 'Unknown'
    END                                             AS is_senior_citizen,
    UPPER(TRIM(PARTNER))                            AS has_partner,
    UPPER(TRIM(DEPENDENTS))                         AS has_dependents,

    -- TENURE & CONTRACT
    TRY_TO_NUMBER(TENUREMONTHS)                     AS tenure_months,
    TRIM(CONTRACT)                                  AS contract_type,
    UPPER(TRIM(PAPERLESSBILLING))                   AS paperless_billing,
    TRIM(PAYMENTMETHOD)                             AS payment_method,

    -- SERVICES
    UPPER(TRIM(PHONESERVICE))                       AS has_phone_service,
    UPPER(TRIM(MULTIPLELINES))                      AS multiple_lines,
    TRIM(INTERNETSERVICE)                           AS internet_service,
    UPPER(TRIM(ONLINESECURITY))                     AS online_security,
    UPPER(TRIM(ONLINEBACKUP))                       AS online_backup,
    UPPER(TRIM(DEVICEPROTECTION))                   AS device_protection,
    UPPER(TRIM(TECHSUPPORT))                        AS tech_support,
    UPPER(TRIM(STREAMINGTV))                        AS streaming_tv,
    UPPER(TRIM(STREAMINGMOVIES))                    AS streaming_movies,

    -- FINANCIALS
    TRY_TO_NUMBER(MONTHLYCHARGES, 10, 2)            AS monthly_charges,
    TRY_TO_NUMBER(TOTALCHARGES, 10, 2)              AS total_charges,

    -- CHURN FLAG
    UPPER(TRIM(CHURN))                              AS churn_flag,
    CASE
        WHEN UPPER(TRIM(CHURN)) = 'YES' THEN 1
        ELSE 0
    END                                             AS is_churned,

    -- DERIVED COLUMNS
    CASE
        WHEN TRY_TO_NUMBER(TENUREMONTHS) <= 12  THEN '0-12 Months'
        WHEN TRY_TO_NUMBER(TENUREMONTHS) <= 24  THEN '13-24 Months'
        WHEN TRY_TO_NUMBER(TENUREMONTHS) <= 48  THEN '25-48 Months'
        ELSE '48+ Months'
    END                                             AS tenure_segment,

    CASE
        WHEN TRY_TO_NUMBER(MONTHLYCHARGES) < 35  THEN 'Low Value'
        WHEN TRY_TO_NUMBER(MONTHLYCHARGES) < 65  THEN 'Mid Value'
        ELSE 'High Value'
    END                                             AS customer_value_segment,

    -- DATA QUALITY FLAG
    CASE
        WHEN NULLIF(TRIM(CUSTOMERID), '') IS NULL
        THEN 'INVALID'
        ELSE 'VALID'
    END                                             AS record_quality,

    -- AUDIT
    CURRENT_TIMESTAMP()                             AS silver_loaded_at

FROM BRONZE.RAW_TELCO_CHURN
WHERE NULLIF(TRIM(CUSTOMERID), '') IS NOT NULL;

-- ============================================================
-- BLOCK 9B: SILVER TABLE — SAAS SALES (CLEANED)
-- ============================================================

CREATE OR REPLACE TABLE SILVER.CLEAN_SAAS_SALES AS
SELECT
    -- ORDER IDENTITY
    TRIM(ROW_ID)                                    AS row_id,
    TRIM(ORDER_ID)                                  AS order_id,

    -- DATE (handling inconsistent M/DD/YYYY format)
    TRY_TO_DATE(ORDER_DATE, 'MM/DD/YYYY')           AS order_date,
    YEAR(TRY_TO_DATE(ORDER_DATE, 'MM/DD/YYYY'))     AS order_year,
    MONTH(TRY_TO_DATE(ORDER_DATE, 'MM/DD/YYYY'))    AS order_month,
    MONTHNAME(TRY_TO_DATE(ORDER_DATE,'MM/DD/YYYY')) AS order_month_name,
    QUARTER(TRY_TO_DATE(ORDER_DATE, 'MM/DD/YYYY'))  AS order_quarter,

    -- CUSTOMER & GEOGRAPHY
    TRIM(CUSTOMER)                                  AS customer_name,
    TRIM(CUSTOMER_ID)                               AS customer_id,
    TRIM(COUNTRY)                                   AS country,
    TRIM(CITY)                                      AS city,
    TRIM(REGION)                                    AS region,
    TRIM(SUBREGION)                                 AS subregion,
    TRIM(INDUSTRY)                                  AS industry,
    TRIM(SEGMENT)                                   AS segment,
    TRIM(CONTACT_NAME)                              AS contact_name,

    -- PRODUCT
    TRIM(PRODUCT)                                   AS product_name,
    TRIM(LICENSE)                                   AS license_type,

    -- DERIVED: Product tier
    CASE
        WHEN UPPER(TRIM(PRODUCT)) LIKE '% - GOLD'
        THEN 'Gold'
        ELSE 'Standard'
    END                                             AS product_tier,

    -- DERIVED: Product category
    CASE
        WHEN UPPER(TRIM(PRODUCT)) LIKE '%MARKETING%'  THEN 'Marketing'
        WHEN UPPER(TRIM(PRODUCT)) LIKE '%STORAGE%'    THEN 'Infrastructure'
        WHEN UPPER(TRIM(PRODUCT)) LIKE '%DATABASE%'   THEN 'Infrastructure'
        WHEN UPPER(TRIM(PRODUCT)) LIKE '%ANALYTICS%'  THEN 'Analytics'
        WHEN UPPER(TRIM(PRODUCT)) LIKE '%FINANCE%'    THEN 'Finance'
        WHEN UPPER(TRIM(PRODUCT)) LIKE '%SUPPORT%'    THEN 'Support'
        WHEN UPPER(TRIM(PRODUCT)) LIKE '%CONNECTOR%'  THEN 'Integration'
        ELSE 'Other'
    END                                             AS product_category,

    -- FINANCIALS
    TRY_TO_NUMBER(SALES, 10, 2)                     AS sales_amount,
    TRY_TO_NUMBER(QUANTITY)                         AS quantity,
    TRY_TO_NUMBER(DISCOUNT, 10, 4)                  AS discount_rate,
    TRY_TO_NUMBER(PROFIT, 10, 2)                    AS profit_amount,

    -- DERIVED: Profit margin %
    CASE
        WHEN TRY_TO_NUMBER(SALES, 10, 2) > 0
        THEN ROUND(
            TRY_TO_NUMBER(PROFIT, 10, 2) /
            TRY_TO_NUMBER(SALES, 10, 2) * 100, 2)
        ELSE 0
    END                                             AS profit_margin_pct,

    -- DERIVED: Revenue tier
    CASE
        WHEN TRY_TO_NUMBER(SALES, 10, 2) = 0      THEN 'Free/Zero'
        WHEN TRY_TO_NUMBER(SALES, 10, 2) < 100    THEN 'Low'
        WHEN TRY_TO_NUMBER(SALES, 10, 2) < 1000   THEN 'Medium'
        ELSE 'High'
    END                                             AS revenue_tier,

    -- DATA QUALITY FLAGS
    CASE
        WHEN TRY_TO_NUMBER(SALES, 10, 2) = 0
        THEN 'ZERO_SALES'
        WHEN TRY_TO_NUMBER(PROFIT, 10, 2) < -1000
        THEN 'HIGH_LOSS'
        ELSE 'NORMAL'
    END                                             AS record_flag,

    -- AUDIT
    CURRENT_TIMESTAMP()                             AS silver_loaded_at

FROM BRONZE.RAW_SAAS_SALES;

-- ============================================================
-- BLOCK 9C: VERIFY SILVER TABLES
-- ============================================================

-- Row counts
SELECT COUNT(*) AS telco_silver_rows FROM SILVER.CLEAN_TELCO_CHURN;
SELECT COUNT(*) AS saas_silver_rows  FROM SILVER.CLEAN_SAAS_SALES;

-- Churn distribution
SELECT
    churn_flag,
    COUNT(*)                                        AS customer_count,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER(), 2)                  AS percentage
FROM SILVER.CLEAN_TELCO_CHURN
GROUP BY churn_flag;

-- Product tier revenue
SELECT
    product_tier,
    product_category,
    COUNT(*)                                        AS transaction_count,
    ROUND(SUM(sales_amount), 2)                     AS total_sales
FROM SILVER.CLEAN_SAAS_SALES
GROUP BY product_tier, product_category
ORDER BY total_sales DESC;

-- Data quality flags
SELECT record_flag, COUNT(*)
FROM SILVER.CLEAN_SAAS_SALES
GROUP BY record_flag;

-- ============================================================
-- EXPECTED OUTPUT:
-- CLEAN_TELCO_CHURN  → 7,043 rows
-- CLEAN_SAAS_SALES   → 9,994 rows
-- Churn rate         → 26.54% YES / 73.46% NO
-- High loss records  → 22 transactions
-- ============================================================
