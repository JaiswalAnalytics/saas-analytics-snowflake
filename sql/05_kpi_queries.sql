-- ============================================================
-- PROJECT: SaaS Analytics on Snowflake
-- AUTHOR:  Shubham Jaiswal (@JaiswalAnalytics)
-- FILE:    05_kpi_queries.sql
-- DESC:    8 Advanced KPI Queries powering Power BI Dashboard
-- ============================================================

USE WAREHOUSE SAAS_WH;
USE DATABASE SAAS_ANALYTICS;

-- ============================================================
-- QUERY 1: MONTHLY REVENUE TREND (MoM Growth)
-- ============================================================
-- Business Question: What is our monthly revenue trend
-- and how does growth compare month over month?

SELECT
    d.year,
    d.month_number,
    d.month_name,
    d.quarter_label,
    COUNT(DISTINCT f.order_id)              AS total_orders,
    ROUND(SUM(f.sales_amount), 2)           AS monthly_revenue,
    ROUND(SUM(f.profit_amount), 2)          AS monthly_profit,
    ROUND(AVG(f.profit_margin_pct), 2)      AS avg_margin_pct,

    -- Month over Month Revenue Growth using LAG()
    ROUND(
        (SUM(f.sales_amount) - LAG(SUM(f.sales_amount))
            OVER (ORDER BY d.year, d.month_number))
        / NULLIF(LAG(SUM(f.sales_amount))
            OVER (ORDER BY d.year, d.month_number), 0) * 100
    , 2)                                    AS mom_growth_pct

FROM GOLD.FACT_REVENUE f
JOIN GOLD.DIM_DATE d ON f.date_id = d.date_id
GROUP BY d.year, d.month_number, d.month_name, d.quarter_label
ORDER BY d.year, d.month_number;

-- ============================================================
-- QUERY 2: REVENUE BY REGION
-- ============================================================
-- Business Question: Which regions generate the most
-- revenue and profit? Where are we losing money?

SELECT
    g.region,
    g.subregion,
    COUNT(DISTINCT f.order_id)              AS total_orders,
    COUNT(DISTINCT f.customer_id)           AS unique_customers,
    ROUND(SUM(f.sales_amount), 2)           AS total_revenue,
    ROUND(SUM(f.profit_amount), 2)          AS total_profit,
    ROUND(AVG(f.profit_margin_pct), 2)      AS avg_margin_pct,
    ROUND(SUM(f.sales_amount) /
          COUNT(DISTINCT f.order_id), 2)    AS avg_order_value,

    -- Revenue share %
    ROUND(SUM(f.sales_amount) * 100 /
          SUM(SUM(f.sales_amount)) OVER (), 2) AS revenue_share_pct

FROM GOLD.FACT_REVENUE f
JOIN GOLD.DIM_GEOGRAPHY g
  ON f.geography_key = g.geography_key
GROUP BY g.region, g.subregion
ORDER BY total_revenue DESC;

-- ============================================================
-- QUERY 3: PRODUCT PROFITABILITY MATRIX
-- ============================================================
-- Business Question: Which products are profitable?
-- Which are losing money and why?

SELECT
    p.product_category,
    p.product_name,
    p.product_tier,
    COUNT(*)                                AS total_transactions,
    ROUND(SUM(f.sales_amount), 2)           AS total_revenue,
    ROUND(SUM(f.profit_amount), 2)          AS total_profit,
    ROUND(AVG(f.profit_margin_pct), 2)      AS avg_margin_pct,
    ROUND(AVG(f.sales_amount), 2)           AS avg_deal_size,
    ROUND(AVG(f.discount_rate) * 100, 2)    AS avg_discount_pct,

    -- Rank products by revenue within category
    RANK() OVER (
        PARTITION BY p.product_category
        ORDER BY SUM(f.sales_amount) DESC
    )                                       AS revenue_rank_in_category,

    -- Profitability flag
    CASE
        WHEN AVG(f.profit_margin_pct) < 0   THEN 'Unprofitable'
        WHEN AVG(f.profit_margin_pct) < 10  THEN 'Low Margin'
        WHEN AVG(f.profit_margin_pct) < 25  THEN 'Healthy'
        ELSE 'High Margin'
    END                                     AS profitability_flag

FROM GOLD.FACT_REVENUE f
JOIN GOLD.DIM_PRODUCT p
  ON f.product_key = p.product_key
GROUP BY p.product_category, p.product_name, p.product_tier
ORDER BY total_revenue DESC;

-- ============================================================
-- QUERY 4: TOP 10 CUSTOMERS BY REVENUE
-- ============================================================
-- Business Question: Who are our most valuable customers?
-- How long have they been with us?

SELECT TOP 10
    f.customer_name,
    f.customer_id,
    f.segment,
    f.industry,
    COUNT(DISTINCT f.order_id)              AS total_orders,
    ROUND(SUM(f.sales_amount), 2)           AS total_revenue,
    ROUND(SUM(f.profit_amount), 2)          AS total_profit,
    ROUND(AVG(f.profit_margin_pct), 2)      AS avg_margin_pct,
    MIN(f.date_id)                          AS first_order_date,
    MAX(f.date_id)                          AS last_order_date,
    DATEDIFF('month',
        MIN(f.date_id),
        MAX(f.date_id))                     AS customer_lifespan_months,
    RANK() OVER (
        ORDER BY SUM(f.sales_amount) DESC
    )                                       AS revenue_rank
FROM GOLD.FACT_REVENUE f
GROUP BY
    f.customer_name,
    f.customer_id,
    f.segment,
    f.industry
ORDER BY total_revenue DESC;

-- ============================================================
-- QUERY 5: CHURN ANALYSIS BY CONTRACT TYPE
-- ============================================================
-- Business Question: Which contract types have the highest
-- churn? How much revenue are we losing?

SELECT
    c.contract_type,
    COUNT(*)                                AS total_customers,
    SUM(f.is_churned)                       AS churned_customers,
    COUNT(*) - SUM(f.is_churned)            AS retained_customers,
    ROUND(SUM(f.is_churned) * 100.0 /
          COUNT(*), 2)                      AS churn_rate_pct,
    ROUND(AVG(f.monthly_charges), 2)        AS avg_monthly_charges,
    ROUND(AVG(f.tenure_months), 2)          AS avg_tenure_months,
    ROUND(SUM(f.lost_annual_revenue), 2)    AS total_lost_revenue,
    ROUND(AVG(f.customer_ltv), 2)           AS avg_customer_ltv
FROM GOLD.FACT_CHURN f
JOIN GOLD.DIM_CUSTOMER c
  ON f.customer_key = c.customer_key
GROUP BY c.contract_type
ORDER BY churn_rate_pct DESC;

-- ============================================================
-- QUERY 6: HIGH RISK CUSTOMER WATCHLIST
-- ============================================================
-- Business Question: Which active customers are most likely
-- to churn? Who should the retention team contact first?

SELECT
    f.customer_id,
    c.contract_type,
    c.payment_method,
    c.internet_service,
    c.tenure_segment,
    c.customer_value_segment,
    f.tenure_months,
    f.monthly_charges,
    f.total_charges,
    f.churn_risk_segment,
    f.lost_annual_revenue,
    f.customer_ltv,
    f.churn_flag,

    -- Composite risk score (0-100)
    (
        CASE WHEN c.contract_type = 'Month-to-month'
             THEN 40 ELSE 0 END
        +
        CASE WHEN f.tenure_months <= 12 THEN 30
             WHEN f.tenure_months <= 24 THEN 15
             ELSE 0 END
        +
        CASE WHEN f.monthly_charges > 65 THEN 20
             WHEN f.monthly_charges > 35 THEN 10
             ELSE 0 END
        +
        CASE WHEN c.internet_service = 'Fiber optic'
             THEN 10 ELSE 0 END
    )                                       AS risk_score

FROM GOLD.FACT_CHURN f
JOIN GOLD.DIM_CUSTOMER c
  ON f.customer_key = c.customer_key
WHERE f.churn_risk_segment = 'High Risk'
  AND f.is_churned = 0
ORDER BY risk_score DESC, f.monthly_charges DESC
LIMIT 20;

-- ============================================================
-- QUERY 7: CUSTOMER LTV BY SEGMENT
-- ============================================================
-- Business Question: Which customer segments generate
-- the most lifetime value?

SELECT
    c.customer_value_segment,
    c.contract_type,
    COUNT(*)                                AS customer_count,
    ROUND(AVG(f.customer_ltv), 2)           AS avg_ltv,
    ROUND(MIN(f.customer_ltv), 2)           AS min_ltv,
    ROUND(MAX(f.customer_ltv), 2)           AS max_ltv,
    ROUND(SUM(f.customer_ltv), 2)           AS total_ltv,
    ROUND(AVG(f.tenure_months), 2)          AS avg_tenure_months,
    ROUND(AVG(f.monthly_charges), 2)        AS avg_monthly_charges,
    SUM(f.is_churned)                       AS churned_count,
    ROUND(SUM(f.is_churned) * 100.0 /
          COUNT(*), 2)                      AS churn_rate_pct
FROM GOLD.FACT_CHURN f
JOIN GOLD.DIM_CUSTOMER c
  ON f.customer_key = c.customer_key
GROUP BY c.customer_value_segment, c.contract_type
ORDER BY avg_ltv DESC;

-- ============================================================
-- QUERY 8: YEARLY PERFORMANCE SUMMARY (YoY Growth)
-- ============================================================
-- Business Question: How has our business grown year
-- over year? Is growth accelerating or slowing?

SELECT
    d.year,
    COUNT(DISTINCT f.order_id)              AS total_orders,
    COUNT(DISTINCT f.customer_id)           AS unique_customers,
    ROUND(SUM(f.sales_amount), 2)           AS annual_revenue,
    ROUND(SUM(f.profit_amount), 2)          AS annual_profit,
    ROUND(AVG(f.profit_margin_pct), 2)      AS avg_margin_pct,
    ROUND(SUM(f.sales_amount) /
          COUNT(DISTINCT f.customer_id), 2) AS revenue_per_customer,

    -- Year over Year Growth using LAG()
    ROUND(
        (SUM(f.sales_amount) - LAG(SUM(f.sales_amount))
            OVER (ORDER BY d.year))
        / NULLIF(LAG(SUM(f.sales_amount))
            OVER (ORDER BY d.year), 0) * 100
    , 2)                                    AS yoy_growth_pct

FROM GOLD.FACT_REVENUE f
JOIN GOLD.DIM_DATE d
  ON f.date_id = d.date_id
GROUP BY d.year
ORDER BY d.year;

-- ============================================================
-- EXPECTED OUTPUTS:
-- Query 1: 48 months of data (Jan 2020 - Dec 2023)
-- Query 2: 12 subregions, JAPN & ANZ negative profit
-- Query 3: 14 products, 4 unprofitable
-- Query 4: Anthem #1 at $55,719
-- Query 5: Month-to-month 42.71% churn
-- Query 6: 20 high-risk customers, all risk score 100
-- Query 7: Two year LTV 2.7x higher than monthly
-- Query 8: 2022 best YoY growth at +29.32%
-- ============================================================
