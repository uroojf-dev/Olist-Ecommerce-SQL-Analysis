/*
===============================================================================
Olist E-Commerce SQL Case Study
===============================================================================
A pure-SQL analysis of the Brazilian E-Commerce Public Dataset by Olist,
exploring revenue trends, delivery performance, customer retention, and
seller rankings across a multi-table relational database.

Database: olist.db (SQLite), built from 8 source CSVs
Tables: orders, order_items, order_payments, order_reviews, customers,
        products, sellers, category_translation

Run instructions: see README.md in this repository.
===============================================================================
*/


-- ===========================================================================
-- 1. Order status breakdown
-- What does the overall order pipeline look like?
-- ===========================================================================
SELECT
    order_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- ===========================================================================
-- 2. Total revenue and average order value
-- What is total revenue, and what's the typical order size?
-- Only "delivered" orders are counted as completed sales.
-- ===========================================================================
SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- ===========================================================================
-- 3. Monthly revenue trend
-- How does revenue trend over time? Is the business growing?
-- ===========================================================================
SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;


-- ===========================================================================
-- 4. Top 10 product categories by revenue
-- Which product categories drive the most revenue?
-- Chains three joins to translate the Portuguese category name to English.
-- ===========================================================================
SELECT
    ct.product_category_name_english AS category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY total_revenue DESC
LIMIT 10;


-- ===========================================================================
-- 5. Late delivery rate
-- What percentage of delivered orders arrived late?
-- ===========================================================================
SELECT
    COUNT(*) AS total_delivered_orders,
    SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) / COUNT(*), 2) AS late_pct
FROM orders
WHERE order_status = 'delivered';


-- ===========================================================================
-- 6. Delivery lateness vs. review score
-- Do late deliveries hurt customer satisfaction?
-- ===========================================================================
SELECT
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,
    COUNT(*) AS num_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY delivery_status;


-- ===========================================================================
-- 7. Revenue by customer state
-- Which states generate the most revenue?
-- ===========================================================================
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC
LIMIT 10;


-- ===========================================================================
-- 8. Cumulative monthly revenue
-- What does the cumulative growth trajectory look like?
-- Uses a CTE plus a window function (SUM ... OVER) for a running total.
-- ===========================================================================
WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
        ROUND(SUM(oi.price), 2) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    ROUND(SUM(revenue) OVER (ORDER BY order_month), 2) AS cumulative_revenue
FROM monthly_revenue
ORDER BY order_month;


-- ===========================================================================
-- 9. Repeat customer rate
-- What percentage of customers come back and order again?
-- Uses customer_unique_id (not customer_id) since Olist assigns a new
-- customer_id on every order; customer_unique_id is the true person-level key.
-- ===========================================================================
WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS num_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN num_orders = 1 THEN 1 ELSE 0 END) AS one_time_customers,
    SUM(CASE WHEN num_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN num_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_customer_pct
FROM customer_order_counts;


-- ===========================================================================
-- 10. Top seller per product category
-- Which seller generates the most revenue within each category?
-- A "top N per group" problem using RANK() with PARTITION BY.
-- ===========================================================================
WITH seller_category_revenue AS (
    SELECT
        ct.product_category_name_english AS category,
        oi.seller_id,
        ROUND(SUM(oi.price), 2) AS seller_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN category_translation ct ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY category, oi.seller_id
),
ranked_sellers AS (
    SELECT
        category,
        seller_id,
        seller_revenue,
        RANK() OVER (PARTITION BY category ORDER BY seller_revenue DESC) AS revenue_rank
    FROM seller_category_revenue
)
SELECT *
FROM ranked_sellers
WHERE revenue_rank = 1
ORDER BY seller_revenue DESC
LIMIT 10;


-- ===========================================================================
-- 11. Payment method behavior
-- How do customers prefer to pay?
-- ===========================================================================
SELECT
    payment_type,
    COUNT(*) AS num_payments,
    ROUND(AVG(payment_installments), 1) AS avg_installments,
    ROUND(AVG(payment_value), 2) AS avg_payment_value
FROM order_payments
WHERE payment_type != 'not_defined'
GROUP BY payment_type
ORDER BY num_payments DESC;
