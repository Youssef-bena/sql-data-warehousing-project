# Data Catalog — CRM + ERP Sales Analytics

**Project:** CRM + ERP Sales Analytics Dashboard  
**Data range:** 1 Jan 2011 – 31 Dec 2013  
**Last updated:** March 2026 
**Model:** Power BI Desktop — sales_dashboard.pbix  
**Server:** DESKTOP-H76U7GH\SQLEXPRESS / DataWarehouse (gold schema)

---

## Contents

1. [Model Overview](#1-model-overview)
2. [Table: gold fact_sales](#2-table-gold-fact_sales)
3. [Table: gold dim_customers](#3-table-gold-dim_customers)
4. [Table: gold dim_products](#4-table-gold-dim_products)
5. [Table: dim_date](#5-table-dim_date)
6. [Helper Tables](#6-helper-tables)
7. [Measures](#7-measures)
8. [Relationships](#8-relationships)
9. [Data Quality Notes](#9-data-quality-notes)

---

## 1. Model Overview

| Item | Detail |
|------|--------|
| Architecture | Medallion (Bronze → Silver → Gold) in SQL Server Express |
| Grain | One row per order line (order_number + product_key) |
| Fact table | gold fact_sales — 45,205 rows in scope |
| Dimension tables | gold dim_customers, gold dim_products, dim_date |
| Helper tables | _Measures|
| Active relationships | 4 |
| Inactive relationships | 2 (role-playing dates on dim_date) |
| **Measures** | **35**  |
| Calculated columns | 9 on fact_sales · 5 on dim_customers · 1 on dim_products |

---

## 2. Table: gold fact_sales

**Type:** Fact  
**Rows:** 45,205 in scope (2011–2013)  
**Grain:** One row per order line — unique combination of order_number + product_key  
**Source:** gold.fact_sales in DataWarehouse

| Column | Type | Calculated | Description |
|--------|------|:---------:|-------------|
| `order_number` | String | | Unique transaction identifier. `SO` prefix = sale. `SR` prefix = return. Drives all status-based measure filters. |
| `product_key` | Int64 | | Foreign key to gold dim_products. Hidden from reports. |
| `customer_key` | Int64 | | Foreign key to gold dim_customers. Hidden from reports. |
| `order_date` | DateTime | | Date the customer placed the order. Primary date column — active relationship to dim_date is on this column. |
| `shipping_date` | DateTime | | Date the order was dispatched. Linked to dim_date via inactive relationship. Use USERELATIONSHIP() to analyse by shipping date. |
| `due_date` | DateTime | | Expected delivery date. Linked to dim_date via inactive relationship. Use USERELATIONSHIP() to analyse by due date. |
| `sales_amount` | Int64 | | Total line revenue = sales_price × quantity. Raw column summed by all Sales Amount measures. |
| `quantity` | Int64 | | Units ordered on this line. Filtered to SO or SR rows in Quantity Sold / Returned measures. |
| `sales_price` | Int64 | | Unit selling price for this order line. Used in return rate thresholds (≥$540 = high-value tier). |
| `estimated_cost` | Decimal | ✓ | quantity × unit cost from dim_products. Basis for profit and margin calculations. |
| `estimated_profit` | Decimal | ✓ | sales_amount − estimated_cost. Blank for zero-cost products. |
| `margin_pct` | Decimal | ✓ | estimated_profit ÷ sales_amount. Format: 0.00%. Blank when sales_amount = 0. |
| `shipping_lead_days` | Int64 | ✓ | Engineered lead time in days. Base by product line (Touring=10, Road=9, Mountain=8, n/a=6, Other Sales=5) + country modifier (AU/DE/FR +2d, UK +1d, US/CA 0d) + deterministic jitter ±2d. Range: 3–15d. |
| `on_time_flag` | Boolean | ✓ | TRUE if shipping_lead_days ≤ 12. All late deliveries are in Road and Touring lines shipped to AU, FR, DE, UK. |
| `lead_time_band` | String | ✓ | `1-Fast (≤5d)` / `2-Standard (6-8d)` / `3-Slow (9-11d)` / `4-Critical (12+d)`. Number prefix ensures correct sort order. All late deliveries are in the Critical band. |
| `is_returned` | Boolean | ✓ | Deterministic return flag. ~8–10% rate on items with sales_price ≥ $540, ~2.5% on $30–$539. Reproducible via order number modulo logic. |
| `return_amount` | Decimal | ✓ | sales_amount for returned rows (is_returned = TRUE), BLANK otherwise. |
| `return_quantity` | Int64 | ✓ | quantity for returned rows (is_returned = TRUE), BLANK otherwise. |

---

## 3. Table: gold dim_customers

**Type:** Dimension  
**Rows:** 18,484  
**Grain:** One row per customer  
**Source:** gold.dim_customers in DataWarehouse

| Column | Type | Calculated | Description |
|--------|------|:---------:|-------------|
| `customer_key` | Int64 | | Primary surrogate key. Hidden from reports. |
| `customer_id` | Int64 | | Original source system ID. Hidden — kept for traceability. |
| `customer_number` | String | | Business-facing customer code. Hidden — use full_name in visuals. |
| `first_name` | String | | Customer given name. Use full_name in visuals instead. |
| `last_name` | String | | Customer family name. Use full_name in visuals instead. |
| `country` | String | | Customer country. 337 rows have country = `n/a` — exclude from country-level visuals with a visual-level filter. |
| `marital_status` | String | | Single or Married. Use for demographic segmentation. Single customers outperform Married by ~$120–$135 AOV. |
| `gender` | String | | Customer gender. Use for demographic breakdowns on Page 4 heatmap. |
| `birth_date` | DateTime | | Date of birth. Used to calculate `age` and `age_group`. |
| `customer_since` | DateTime | | Account creation date. Use for customer tenure and cohort analysis. |
| `age` | Int64 | ✓ | Current age in years from birth_date to TODAY(). Basis for age_group. Blank when birth_date is missing. |
| `age_group` | String | ✓ | Age band: Under 25 / 25-34 / 35-44 / 45-54 / 55-64 / 65+ / Unknown. Sort by `age` column for correct order. |
| `rfm_segment` | String | ✓ | 7-segment RFM label anchored to 31 Dec 2013. R/F/M each scored 1–3. Segments: Champion / Loyal / Potential Loyalist / New Customer / At Risk / Hibernating / Needs Attention. |
| `customer_spend_band` | String | ✓ | Lifetime spend tier: `1-Under $500` (9,209) / `2-$500–$999` (1,555) / `3-$1K–$2.4K` (3,111) / `4-$2.5K–$4.9K` (2,648) / `5-$5K+` (1,308) / `6-No Purchase` (653). Used as X axis on Pareto chart (Page 1). |
| `full_name` | String | ✓ | first_name + " " + last_name. Use this in all visuals instead of the two separate name columns. |
| `Customer Type` | String | ✓ | `New` (1 order) or `Repeat` (2+ orders). Per customer key across the full dataset. Used in Legend field of stacked bar on Page 4. |

---

## 4. Table: gold dim_products

**Type:** Dimension  
**Rows:** 295  
**Grain:** One row per product  
**Source:** gold.dim_products in DataWarehouse

| Column | Type | Calculated | Description |
|--------|------|:---------:|-------------|
| `product_key` | Int64 | | Primary surrogate key. Hidden from reports. |
| `product_id` | Int64 | | Original source system ID. Hidden — kept for traceability. |
| `product_number` | String | | Alphanumeric product code (e.g. BK-M18B-40). Hidden — use product_name in visuals. |
| `product_name` | String | | Full product name. Primary display field for product-level filtering and grouping. |
| `category_id` | String | | Surrogate category ID. Hidden — use `category` column instead. |
| `category` | String | | Top-level product grouping: Bikes / Accessories / Clothing / Components. Components has 127 SKUs and $0 revenue — exclude from visuals using a Net Sales > 0 filter. |
| `subcategory` | String | | Second-level grouping within category (e.g. Road Bikes). Use for product drill-downs below category level. |
| `has_maintenance` | String | | Original string flag (Yes/No). Hidden — replaced by `is_maintenance` Boolean column. |
| `cost` | Int64 | | Standard unit cost. Used in estimated_cost and margin calculations. 2 products have cost = 0 — their margin will be overstated. |
| `product_line` | String | | Product family: Road / Mountain / Touring / Other Sales / n/a. Use for portfolio-level analysis. |
| `start_date` | DateTime | | Date the product version became active. Use to filter to currently active products. |
| `is_maintenance` | Boolean | ✓ | TRUE = product requires maintenance. Boolean replacement for has_maintenance. Use in slicers and the [Maintenance Flag] measure. |

---

## 5. Table: dim_date

**Type:** Dimension (DAX calculated table — not from SQL)  
**Rows:** 1,826 (1 Jan 2010 – 31 Dec 2014)  
**Grain:** One row per calendar date  
**Source:** DAX CALENDAR() expression

| Column | Type | Description |
|--------|------|-------------|
| `Date` | DateTime | Full calendar date. Primary key. Column used in all active and inactive relationships and all time intelligence functions. |
| `DateKey` | Int64 | Date as YYYYMMDD integer. Hidden — used for sorting and fast joins. |
| `Year` | Int64 | 4-digit year. Use for year-level grouping and Year slicer. |
| `Quarter` | Int64 | Quarter number 1–4. Pair with QuarterName for readable labels. |
| `QuarterName` | String | Readable quarter label: Q1 / Q2 / Q3 / Q4. |
| `YearQuarter` | String | Combined label e.g. 2023-Q1. Use on quarterly time-series charts. |
| `Month` | Int64 | Month number 1–12. Always use this to sort MonthName — prevents alphabetical ordering. |
| `MonthName` | String | Full month name e.g. January. Set sort-by to Month column. |
| `MonthShort` | String | 3-letter abbreviation e.g. Jan. Use in space-constrained visuals. |
| `YearMonth` | Int64 | Integer YYYYMM e.g. 202304. Used to sort YearMonthName. |
| `YearMonthName` | String | Combined label e.g. 2023-Apr. Use as X axis on monthly charts. Sort by YearMonth. |
| `WeekNumber` | Int64 | ISO week number 1–53 (weeks start Monday). Use for weekly trend analysis. |
| `DayOfWeek` | Int64 | Day number 1 (Monday) to 7 (Sunday). Used to sort DayOfWeekName. |
| `DayOfWeekName` | String | Full weekday name e.g. Monday. Sort by DayOfWeek. |
| `DayOfWeekShort` | String | 3-letter abbreviation e.g. Mon. Sort by DayOfWeek. |
| `DayOfMonth` | Int64 | Day number within the month 1–31. Use for within-month daily analysis. |
| `DayOfYear` | Int64 | Sequential day number within the year 1–366. Use for year-over-year daily comparisons on a common axis. |
| `IsWeekend` | Boolean | TRUE if Saturday or Sunday. Use to segment weekday vs weekend performance. |
| `IsWeekday` | Boolean | TRUE if Monday–Friday. Complement of IsWeekend. |

---

## 6. Helper Tables

### _Measures

Calculation-only table with no data rows. Contains all 35 DAX measures in 5 display folders. Never used as a visual axis or filter.

---

## 7. Measures

All 35 measures are in the `_Measures` table, organised in 5 folders.

### Folder 1 — Base Measures

| Measure | Format | Used on | Description |
|---------|--------|---------|-------------|
| `Sales Amount - Sold` | $#,##0 | P1, P2 tooltips | Gross revenue from all SO orders. Basis for Net Sales. |
| `Sales Amount - Returned` | $#,##0 | P1 KPI, P2 | Total returned order value (SR orders). |
| `Net Sales` | $#,##0 | All pages | Sales Amount - Sold minus Sales Amount - Returned. Primary revenue measure. |
| `Quantity Sold` | #,##0 | P1, P3 | Total units shipped on SO orders. |
| `Quantity Returned` | #,##0 | P2 | Total units returned on SR orders. |
| `Return Rate (Value)` | 0.0% | P1 KPI, P2 | Returned revenue ÷ gross sold revenue. Overall: 11.9%. |
| `Return Rate (Units)` | 0.0% | P2 | Returned units ÷ units sold. Overall: 3.7%. |
| `Orders` | #,##0 | P1, P4, P5 | Count of distinct order numbers. Fact table is at order-line grain. |
| `Orders MOM` | #,##0 | P1 tooltip | Month-on-month change in distinct order count. |

### Folder 2 — Time Intelligence

Sub-folder: **Sales Sold**

| Measure | Format | Used on | Description |
|---------|--------|---------|-------------|
| `Sales Amount - Sold PY` | $#,##0 | Internal only | Prior year gross sold revenue. DAX dependency for Net Sales YOY and YOY %. Not placed in any visual. |

Sub-folder: **Net Sales**

| Measure | Format | Used on | Description |
|---------|--------|---------|-------------|
| `Net Sales MOM` | $#,##0 | P1 tooltip, P2 | Absolute month-on-month change in Net Sales. |
| `Net Sales MOM %` | 0.0% | P1 KPI tooltip | Percentage month-on-month change in Net Sales. |
| `Net Sales PY` | $#,##0 | P1 line chart | Net Sales for the same period last year. Used as comparison line on the dual-axis chart. Also a DAX dependency for YOY measures. |
| `Net Sales YOY` | $#,##0 | P1 | Absolute year-on-year change in Net Sales. |
| `Net Sales YOY %` | 0.0% | P1 | Percentage year-on-year change in Net Sales. Headline performance metric. |

### Folder 3 — Profitability

| Measure | Format | Used on | Description |
|---------|--------|---------|-------------|
| `Gross Profit` | $#,##0 | P1, P3 | SUMX of (sales_amount − estimated_cost) per row. |
| `Gross Margin %` | 0.0% | P1 KPI, P3 scatter | Gross Profit ÷ Net Sales. Overall: 45.1%. |
| `Avg Selling Price` | $#,##0.00 | P3 | Net Sales ÷ Quantity Sold. Tracks price per unit. |
| `Gross Profit MOM` | $#,##0 | P1 line tooltip | Absolute month-on-month change in Gross Profit. |
| `Maintenance Flag` | Text | P3 table | Displays ✔ Maintenance or ✖ Regular. Use instead of raw is_maintenance column. |
| `Maintenance Flag Color` | Integer | P3 table | Conditional formatting helper. ≥1 → green #375623, <1 → grey #595959. |

### Folder 4 — Operational

| Measure | Format | Used on | Description |
|---------|--------|---------|-------------|
| `On-Time Deliveries` | #,##0 | P5 matrix tooltip | Orders with shipping_lead_days ≤ 12. Numerator for On-Time Rate. |
| `Late Deliveries` | #,##0 | P5 combo chart, table | Orders breaching the 12-day threshold. 100% in Road and Touring to AU, FR, DE, UK. |
| `On-Time Rate` | 0.0% | P1 KPI, P5 matrix, combo, scatter | On-Time Deliveries ÷ Orders. Overall: 95.9%. |
| `On-Time Rate MOM` | 0.0% | P5 combo tooltip | Month-on-month change in On-Time Rate (percentage points). |
| `Avg Shipping Lead Days` | 0.0 | P5 scatter tooltip, table | Average shipping_lead_days in filter context. |
| `Late Delivery Revenue` | $#,##0 | P5 table | Net Sales from late-delivered orders. Total: $1,941,808. |
| `Orders (Late %)` | 0.0% | P5 table | Percentage of orders with at least one late delivery line. |

### Folder 5 — Customer

| Measure | Format | Used on | Description |
|---------|--------|---------|-------------|
| `Customers` | #,##0 | P1, P4 | Distinct customer count in filter context. |
| `Avg Order Value` | $#,##0 | P1 KPI, P4 heatmap, grouped bar | Net Sales ÷ distinct order count. Overall: $963. |
| `Orders per Customer` | 0.00 | P4 scatter | Orders ÷ Customers. Above 1 = repeat purchasing. |
| `Repeat Customers` | #,##0 | P4 stacked bar | Customers with more than 1 distinct order. |
| `Repeat Rate` | 0.0% | P4 | Repeat Customers ÷ Customers. Grew 0% → 15.3% from 2011 to 2013. |
| `Cumulative Revenue %` | 0.0% | P1 Pareto line | Cumulative Net Sales % for Pareto analysis. Used as line overlay on customer spend band bar chart. |

Sub-folder: **RFM**

| Measure | Format | Used on | Description |
|---------|--------|---------|-------------|
| `RFM - Recency (Days)` | #,##0 | P4 ranked table | Days since most recent order per customer. Uses TODAY() — values shift daily. Lower = more recent = better. |

---

## 8. Relationships

| From Table | From Column | To Table | To Column | Status | Cardinality |
|------------|-------------|----------|-----------|:------:|-------------|
| gold fact_sales | product_key | gold dim_products | product_key | ✅ Active | Many-to-One |
| gold fact_sales | customer_key | gold dim_customers | customer_key | ✅ Active | Many-to-One |
| gold fact_sales | order_date | dim_date | Date | ✅ Active | Many-to-One |
| gold fact_sales | shipping_date | dim_date | Date | ❌ Inactive | Many-to-One |
| gold fact_sales | due_date | dim_date | Date | ❌ Inactive | Many-to-One |

**Inactive relationships (role-playing):** To activate in a measure, wrap the calculation in `CALCULATE(..., USERELATIONSHIP('gold fact_sales'[shipping_date], 'dim_date'[Date]))`.

---

## 9. Data Quality Notes

| Issue | Rows affected | Impact | Table |
|-------|:------------:|--------|-------|
| Null `order_date` | 19 | Excluded from all date-filtered visuals and time intelligence measures | gold fact_sales |
| Null `category` | 7 products | Appear as blank in category slicers | gold dim_products |
| `cost = 0` | 2 products | estimated_profit and Gross Margin % are overstated for these SKUs | gold dim_products |
| `country = 'n/a'` | 337 customers | Excluded from country-level visuals via visual-level filter | gold dim_customers |
| Components category | 127 products | $0 revenue across all years — excluded from product visuals via Net Sales > 0 filter | gold dim_products |
| `shipping_lead_days` | All rows | Engineered column — not from source logistics data. Deterministic model by product line and country. | gold fact_sales |
| `is_returned` | ~3.7% of rows | Deterministic flag simulating realistic return rates — not actual source return records. | gold fact_sales |

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| v1.0 | Mar 2026 | Initial model — star schema, 7 tables, 4 active relationships, 30+ measures |
| v1.1 | Mar 2026 | Removed 34 unused measures. Model reduced to 35 measures. No visual or relationship changes. |

---

*Generated from live Power BI model — sales_dashboard.pbix · March 2026 · v1.1*
