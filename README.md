# ❄️ SaaS Analytics on Snowflake
### End-to-End Cloud Data Warehouse | Medallion Architecture | Power BI Dashboard

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![SQL](https://img.shields.io/badge/SQL-4479A1?style=for-the-badge&logo=postgresql&logoColor=white)
![dbt](https://img.shields.io/badge/Architecture-Medallion-orange?style=for-the-badge)

---

## 📊 Live Dashboard
🔗 **[View Power BI Dashboard](https://app.powerbi.com/view?r=eyJrIjoiZjk3ZmM5OWItMTVkNS00ZWU3LTlkYmEtYzQ0NjBlMGVhZDQ0IiwidCI6ImM2ZTU0OWIzLTVmNDUtNDAzMi1hYWU5LWQ0MjQ0ZGM1YjJjNCJ9)**

---

## 🎯 Project Overview

Built a production-grade cloud data warehouse on Snowflake from scratch, implementing 
the **Medallion Architecture** (Bronze → Silver → Gold) across two real-world SaaS 
datasets. Surfaced 8 advanced KPIs and built a 4-page Power BI dashboard revealing 
critical business insights.

### Business Problem
A B2B SaaS company needed a single source of truth to answer:
- Which products are making (or losing) money?
- Which customers are about to churn?
- Where is revenue growing — and where is it leaking?

---

## 🏆 Key Business Findings

| Finding | Impact |
|---------|--------|
| 🔴 Best-selling product loses money | ContactMatcher: $410K revenue at **-19% margin** |
| 💸 $1.45M lost to churn annually | Month-to-month churn at **42.71%** |
| 📈 51.6% growth, zero new customers | $484K → $734K — pure **Net Revenue Retention** |
| 🌍 2 subregions deeply unprofitable | Japan + ANZ: **-$37K profit** despite $255K revenue |
| ⭐ Best margin product undersold | SaaS Connector Gold: **42.31% margin**, least revenue |

---

## 🗄️ Architecture

```
RAW DATA (CSV Files)
       │
       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  BRONZE LAYER   │    │   SILVER LAYER   │    │   GOLD LAYER    │
│  (Raw Schema)   │───▶│  (Clean Schema)  │───▶│  (Mart Schema)  │
│                 │    │                  │    │                 │
│ • Raw CSV load  │    │ • Type casting   │    │ • Star Schema   │
│ • No transforms │    │ • Null handling  │    │ • Fact tables   │
│ • Audit cols    │    │ • Deduplication  │    │ • Dim tables    │
│ • Snowflake     │    │ • Derived cols   │    │ • KPI views     │
│   Stages        │    │ • Business rules │    │ • Power BI ready│
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

---

## 🌟 Star Schema (Gold Layer)

```
                    ┌──────────────────┐
                    │   FACT_REVENUE   │
                    │   (9,994 rows)   │
              ┌────▶│ revenue_key      │◀────┐
              │     │ product_key (FK) │     │
              │     │ geography_key(FK)│     │
              │     │ date_id (FK)     │     │
              │     │ sales_amount     │     │
              │     │ profit_amount    │     │
              │     └──────────────────┘     │
              │                              │
   ┌──────────────────┐         ┌────────────────────┐
   │   DIM_PRODUCT    │         │   DIM_GEOGRAPHY    │
   │   (14 rows)      │         │   (262 rows)       │
   │ product_key (PK) │         │ geography_key (PK) │
   │ product_name     │         │ country            │
   │ product_category │         │ region             │
   │ product_tier     │         │ subregion          │
   └──────────────────┘         └────────────────────┘

   ┌──────────────────┐         ┌────────────────────┐
   │   DIM_DATE       │         │   FACT_CHURN       │
   │   (1,237 rows)   │         │   (7,043 rows)     │
   │ date_id (PK)     │         │ churn_key          │
   │ year             │         │ customer_key (FK)  │
   │ month_name       │         │ is_churned         │
   │ quarter          │         │ monthly_charges    │
   └──────────────────┘         │ customer_ltv       │
                                └────────────────────┘
                                         │
                                         ▼
                                ┌────────────────────┐
                                │   DIM_CUSTOMER     │
                                │   (7,043 rows)     │
                                │ customer_key (PK)  │
                                │ contract_type      │
                                │ tenure_segment     │
                                │ value_segment      │
                                └────────────────────┘
```

---

## 📁 Project Structure

```
saas-analytics-snowflake/
│
├── README.md
│
├── sql/
│   ├── 01_environment_setup.sql     # Warehouse, DB, Schemas, Roles
│   ├── 02_bronze_load.sql           # Stages, tables, COPY INTO
│   ├── 03_silver_transform.sql      # Cleaning, type casting, derived cols
│   ├── 04_gold_schema.sql           # Star schema — facts & dimensions
│   └── 05_kpi_queries.sql           # 8 advanced KPI queries
│
├── screenshots/
│   ├── 01_executive_summary.png
│   ├── 02_churn_retention.png
│   ├── 03_product_performance.png
│   └── 04_customer_geography.png
│
└── docs/
    └── architecture_diagram.png
```

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| **Snowflake** | Cloud Data Warehouse |
| **SQL** | Data transformation & KPI queries |
| **Medallion Architecture** | Bronze → Silver → Gold layers |
| **Star Schema** | Dimensional data modeling |
| **Window Functions** | LAG, RANK, ROW_NUMBER, OVER() |
| **CTEs** | Complex query organization |
| **Power BI** | Dashboard & visualization |
| **DAX** | Dynamic KPI measures |

---

## 📊 Dashboard Pages

| Page | KPIs | Charts |
|------|------|--------|
| **Executive Summary** | Revenue, Profit, Churn Rate, Margin | Monthly trend, Annual revenue, Regional split, YoY growth |
| **Churn & Retention** | Churned customers, Revenue at risk, High risk count, 2yr LTV | Contract churn rate, Risk donut, Watchlist table, LTV comparison |
| **Product Performance** | Top product revenue, Best margin, Unprofitable count, Avg discount | Revenue by product, Margin by product, Category donut, Discount rate |
| **Customer & Geography** | Top customer, Rev per customer, Total profit, Loss subregions | Top 10 customers, Subregion profit, Industry revenue, Rev per customer trend |

---

## 📈 KPI Queries Built

1. **Monthly Revenue Trend** — MoM growth with LAG()
2. **Revenue by Region** — with revenue share %
3. **Product Profitability Matrix** — margin flags
4. **Top 10 Customers** — by revenue
5. **Churn by Contract Type** — rate + LTV
6. **High Risk Watchlist** — composite risk scoring
7. **Customer LTV by Segment** — contract × value matrix
8. **Yearly Performance Summary** — YoY growth

---

## 🗂️ Datasets

| Dataset | Source | Rows | Description |
|---------|--------|------|-------------|
| IBM Telco Customer Churn | Kaggle | 7,043 | Customer churn attributes |
| AWS SaaS Sales | Kaggle | 9,994 | B2B SaaS transactions |

---

## 🚀 How to Reproduce

### Prerequisites
- Snowflake free trial account
- Power BI Desktop (free)

### Steps

```sql
-- 1. Run environment setup
-- sql/01_environment_setup.sql

-- 2. Upload CSVs to Snowflake Stage
-- Then run bronze load
-- sql/02_bronze_load.sql

-- 3. Transform to Silver
-- sql/03_silver_transform.sql

-- 4. Build Gold layer
-- sql/04_gold_schema.sql

-- 5. Run KPI queries
-- sql/05_kpi_queries.sql

-- 6. Connect Power BI to Snowflake Gold layer
-- Load all 6 tables
-- Build relationships as per Star Schema
```

---

## 👤 Author

**Shubham Jaiswal**
- GitHub: [@JaiswalAnalytics](https://github.com/JaiswalAnalytics)
- LinkedIn: https://www.linkedin.com/in/iam-shubhamjaiswal/
- Dashboard: [Live Power BI Report](https://app.powerbi.com/view?r=eyJrIjoiZjk3ZmM5OWItMTVkNS00ZWU3LTlkYmEtYzQ0NjBlMGVhZDQ0IiwidCI6ImM2ZTU0OWIzLTVmNDUtNDAzMi1hYWU5LWQ0MjQ0ZGM1YjJjNCJ9)

---

## ⭐ If you found this useful, please star the repository!

```
#Snowflake #DataAnalytics #SQL #PowerBI 
#MedallionArchitecture #StarSchema #Portfolio
```
