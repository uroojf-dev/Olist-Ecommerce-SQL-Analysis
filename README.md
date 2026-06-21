# Olist E-Commerce SQL Case Study

A pure-SQL analysis of the Brazilian E-Commerce Public Dataset by Olist, exploring revenue trends, delivery performance, customer retention, and seller rankings across a multi-table relational database.

## Overview

This project answers 11 real business questions using only SQL — no Python modeling, no dashboarding — to demonstrate the ability to write production-grade queries directly against a relational schema. The dataset spans ~99,000 orders placed on the Olist marketplace between September 2016 and August 2018, split across 8 related tables.

## Dataset

- **Source:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)
- **Format:** 8 CSVs, loaded into a single SQLite database (`olist.db`)
- **Tables:** `orders`, `order_items`, `order_payments`, `order_reviews`, `customers`, `products`, `sellers`, `category_translation`
- **Scale:** ~99,441 orders, ~112,650 order items, ~103,886 payments

### Schema

`orders` is the central table. Each order belongs to one `customer`, can contain multiple `order_items` (each referencing a `product` and a `seller`), can have one or more `order_payments`, and typically has one `order_review`. Product category names are stored in Portuguese in `products` and require a join to `category_translation` to get the English equivalent.

## Approach

Eleven queries, ordered from simple aggregation to advanced window functions:

1. **Order status breakdown** — understand the overall order pipeline before analyzing anything else
2. **Total revenue and average order value** — baseline business metrics, filtered to completed (`delivered`) orders only
3. **Monthly revenue trend** — uses `strftime()` to bucket orders by month and track growth over time
4. **Top 10 product categories by revenue** — a three-table join chain (orders → order_items → products → category_translation) to translate category names
5. **Late delivery rate** — uses a `CASE WHEN` as a binary flag, summed to calculate a percentage
6. **Delivery lateness vs. review score** — joins in `order_reviews` to connect an operational metric to customer satisfaction
7. **Revenue by customer state** — joins in `customers` to analyze geographic distribution
8. **Cumulative monthly revenue** — a CTE plus a `SUM() OVER (ORDER BY ...)` window function to calculate a running total
9. **Repeat customer rate** — a cohort-style analysis using `customer_unique_id` (not `customer_id`, which resets per order) to correctly identify returning customers
10. **Top seller per product category** — a CTE plus `RANK() OVER (PARTITION BY ...)`, a "top N per group" pattern
11. **Payment method behavior** — analyzes installment usage and payment preferences

## Key Findings

| Metric | Value |
|---|---|
| Total delivered orders | 96,478 |
| Total revenue | $13,221,498.11 |
| Average order value | $137.04 |
| Late delivery rate | 8.11% |
| Repeat customer rate | 3.0% |

**Revenue grew consistently** from a near-zero base in late 2016 to a peak of ~$977,500 in May 2018. November 2017 stands out as a clear outlier ($987,765) — almost certainly a Black Friday effect.

**Health & beauty** was the top-grossing category ($1,233,131.72), narrowly ahead of watches & gifts ($1,166,176.98) and bed, bath & table ($1,023,434.76).

**Delivery reliability has a direct, measurable impact on satisfaction.** Orders delivered after their estimated date averaged a 2.57-star review, compared to 4.29 stars for on-time orders — a 1.72-star gap tied entirely to delivery performance.

**São Paulo (SP) dominates revenue** at $5,067,633.16 — more than triple the next-closest state — but actually has the *lowest* average order value ($125.12) among the top 10 states, suggesting higher order volume rather than higher-value orders drives its lead.

**Customer retention is the clearest opportunity area.** Of 93,358 unique customers, only 3.0% (2,801) placed more than one order — a number that required correctly identifying `customer_unique_id` over `customer_id`, since Olist assigns a new `customer_id` on every single order.

**Credit card dominates payments** (76,795 payments, ~70% of all transactions) with an average of 3.5 installments per purchase, consistent with common Brazilian consumer credit habits.

## Tech Stack

SQL (SQLite) · Python (pandas, sqlite3 — for database setup and query execution only) · Jupyter Notebook

## Skills Demonstrated

- Multi-table JOINs (up to 4 tables chained in a single query)
- Aggregation (`GROUP BY`, `COUNT`, `SUM`, `AVG`)
- `CASE WHEN` for both binary flags and categorical labels
- Date functions (`strftime`) for time-series bucketing
- Common Table Expressions (CTEs) for readable, modular query logic
- Window functions: running totals (`SUM() OVER (ORDER BY ...)`) and ranking (`RANK() OVER (PARTITION BY ...)`)
- Identifying and correctly handling a real-world data modeling gotcha (`customer_id` vs. `customer_unique_id`)
- Translating SQL output into business-relevant findings and recommendations

## How to Run

1. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and place the CSVs in this folder
2. Install dependencies and build the database:

```bash
pip install -r requirements.txt
jupyter notebook SQL_Ecommerce_Analysis.ipynb
```

3. Run the first cell to build `olist.db` from the CSVs
4. Run `analysis_queries.sql` queries directly against `olist.db` using any SQLite client, or run the notebook cells which execute the same queries via `pd.read_sql()`

## Future Improvements

- Incorporate the `geolocation` dataset to map revenue and delivery performance geographically
- Build a customer lifetime value (CLV) calculation segmented by acquisition cohort
- Analyze freight cost as a percentage of order value by region, to investigate shipping cost impact on late deliveries
