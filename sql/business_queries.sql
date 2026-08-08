USE retention_analysis;


-- Q1: Monthly revenue and invoice count
WITH monthly AS (
    SELECT
        DATE_FORMAT(InvoiceDate, '%Y-%m') AS year_month,
        SUM(LineTotal)                    AS revenue,
        COUNT(DISTINCT Invoice)           AS num_invoices
    FROM orders_clean_full
    GROUP BY year_month
)
SELECT *
FROM monthly
ORDER BY year_month;


-- Q2: Repeat vs. one-time customers
WITH customer_orders AS (
    SELECT
        `Customer ID`            AS customer_id,
        COUNT(DISTINCT Invoice)  AS num_orders
    FROM orders_clean_full
    WHERE `Customer ID` IS NOT NULL
    GROUP BY `Customer ID`
),
labeled AS (
    SELECT
        customer_id,
        num_orders,
        CASE WHEN num_orders = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type
    FROM customer_orders
)
SELECT
    customer_type,
    COUNT(*) AS num_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_customers
FROM labeled
GROUP BY customer_type;


-- Q3: Top 10 customers by total spend
SELECT
    `Customer ID`             AS customer_id,
    Country,
    ROUND(SUM(LineTotal), 2)  AS total_spend,
    COUNT(DISTINCT Invoice)   AS num_orders
FROM orders_clean_full
WHERE `Customer ID` IS NOT NULL
GROUP BY `Customer ID`
ORDER BY total_spend DESC
LIMIT 10;


-- Q4: Month-over-month revenue change
WITH monthly AS (
    SELECT
        DATE_FORMAT(InvoiceDate, '%Y-%m') AS year_month,
        SUM(LineTotal)                    AS revenue
    FROM orders_clean_full
    GROUP BY year_month
)
SELECT
    year_month,
    revenue,
    LAG(revenue) OVER (ORDER BY year_month) AS prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY year_month))
        / LAG(revenue) OVER (ORDER BY year_month),
    1) AS pct_change
FROM monthly
ORDER BY year_month;


-- Q5: First order date per customer (cohort assignment)
WITH ranked AS (
    SELECT
        `Customer ID` AS customer_id,
        Invoice,
        InvoiceDate,
        ROW_NUMBER() OVER (PARTITION BY `Customer ID` ORDER BY InvoiceDate) AS order_seq
    FROM orders_clean_full
    WHERE `Customer ID` IS NOT NULL
)
SELECT
    customer_id,
    MIN(InvoiceDate) AS first_order_date
FROM ranked
WHERE order_seq = 1
GROUP BY customer_id
ORDER BY customer_id;


-- Optional: cancelled revenue
SELECT
    ROUND(ABS(SUM(Quantity * Price)), 2) AS cancelled_value,
    COUNT(DISTINCT Invoice)              AS num_cancellation_invoices
FROM orders_cancellations;
