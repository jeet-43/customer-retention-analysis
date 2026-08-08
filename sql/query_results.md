# Phase 3 Query Results

Ran against the `retention_analysis` database in MySQL Workbench, loaded straight from
`orders_clean_full.csv` and `orders_cancellations.csv` using the Table Data Import Wizard
(see `sql/business_queries.sql` for the queries themselves).

Source table: `orders_clean_full`, 1,003,386 rows. Queries that need a Customer ID filter down
to the 5,852 customers with a non-null Customer ID (matches the 776,592-row customer-level
population from `assumptions_log.md`).

---

## Q1: Monthly revenue trend

```sql
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS year_month,
    SUM(LineTotal)                    AS revenue,
    COUNT(DISTINCT Invoice)           AS num_invoices
FROM orders_clean_full
GROUP BY year_month
ORDER BY year_month;
```

| year_month | revenue | num_invoices |
|---|---|---|
| 2009-12 | 798,232.03 | 1671 |
| 2010-01 | 612,455.50 | 1053 |
| 2010-02 | 537,926.69 | 1189 |
| 2010-03 | 761,748.53 | 1647 |
| 2010-04 | 646,474.06 | 1436 |
| 2010-05 | 643,585.64 | 1484 |
| 2010-06 | 697,264.72 | 1615 |
| 2010-07 | 633,076.06 | 1507 |
| 2010-08 | 674,192.89 | 1402 |
| 2010-09 | 869,277.16 | 1789 |
| 2010-10 | 1,094,540.11 | 2244 |
| 2010-11 | 1,429,644.32 | 2719 |
| 2010-12 | 775,714.95 | 1550 |
| 2011-01 | 670,439.46 | 1081 |
| 2011-02 | 507,850.09 | 1093 |
| 2011-03 | 689,716.82 | 1440 |
| 2011-04 | 515,463.08 | 1235 |
| 2011-05 | 740,000.14 | 1668 |
| 2011-06 | 737,683.99 | 1525 |
| 2011-07 | 688,178.12 | 1452 |
| 2011-08 | 724,288.42 | 1339 |
| 2011-09 | 1,028,338.80 | 1818 |
| 2011-10 | 1,103,327.63 | 2005 |
| 2011-11 | 1,452,112.69 | 2751 |
| 2011-12 | 614,495.96 | 816 |

Revenue peaks in November both years (holiday build-up for a gift retailer, makes sense).
December 2011 looks weak at £614K, but that's not a real drop, the dataset only covers
Dec 1 to Dec 9, 2011, so that month is partial. Worth a note in the executive summary so
it doesn't get misread as a Q4 collapse.

---

## Q2: Repeat vs. one-time customers

```sql
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
```

| customer_type | num_customers | pct_of_customers |
|---|---|---|
| One-time | 1618 | 27.6% |
| Repeat | 4234 | 72.4% |

72.4% of customers with an ID came back for at least a second order. That's a solid
baseline number for the repeat purchase rate framing in the README, but it's a single
snapshot across two years, it doesn't say whether that rate is climbing or slipping.
That's what the cohort work in Phase 4 is for.

---

## Q3: Top 10 customers by total spend

```sql
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
```

| customer_id | Country | total_spend | num_orders |
|---|---|---|---|
| 18102.0 | United Kingdom | 580,987.04 | 145 |
| 14646.0 | Netherlands | 526,751.52 | 145 |
| 14156.0 | EIRE | 303,069.88 | 144 |
| 14911.0 | EIRE | 272,252.79 | 373 |
| 17450.0 | United Kingdom | 244,784.25 | 51 |
| 13694.0 | United Kingdom | 195,640.69 | 143 |
| 17511.0 | United Kingdom | 172,132.87 | 60 |
| 16446.0 | United Kingdom | 168,472.50 | 2 |
| 16684.0 | United Kingdom | 147,142.77 | 55 |
| 12415.0 | Australia | 144,033.37 | 24 |

The top two customers (18102, 14646) are almost certainly wholesalers, not individual gift
buyers, 145 orders each is a reorder pattern, not casual shopping. Worth flagging since the
dataset itself notes many customers are wholesale rather than retail.

---

## Q4: Month-over-month revenue change

```sql
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
```

| year_month | revenue | prev_month_revenue | pct_change |
|---|---|---|---|
| 2009-12 | 798,232.03 |  |  |
| 2010-01 | 612,455.50 | 798,232.03 | -23.3% |
| 2010-02 | 537,926.69 | 612,455.50 | -12.2% |
| 2010-03 | 761,748.53 | 537,926.69 | 41.6% |
| 2010-04 | 646,474.06 | 761,748.53 | -15.1% |
| 2010-05 | 643,585.64 | 646,474.06 | -0.4% |
| 2010-06 | 697,264.72 | 643,585.64 | 8.3% |
| 2010-07 | 633,076.06 | 697,264.72 | -9.2% |
| 2010-08 | 674,192.89 | 633,076.06 | 6.5% |
| 2010-09 | 869,277.16 | 674,192.89 | 28.9% |
| 2010-10 | 1,094,540.11 | 869,277.16 | 25.9% |
| 2010-11 | 1,429,644.32 | 1,094,540.11 | 30.6% |
| 2010-12 | 775,714.95 | 1,429,644.32 | -45.7% |
| 2011-01 | 670,439.46 | 775,714.95 | -13.6% |
| 2011-02 | 507,850.09 | 670,439.46 | -24.3% |
| 2011-03 | 689,716.82 | 507,850.09 | 35.8% |
| 2011-04 | 515,463.08 | 689,716.82 | -25.3% |
| 2011-05 | 740,000.14 | 515,463.08 | 43.6% |
| 2011-06 | 737,683.99 | 740,000.14 | -0.3% |
| 2011-07 | 688,178.12 | 737,683.99 | -6.7% |
| 2011-08 | 724,288.42 | 688,178.12 | 5.2% |
| 2011-09 | 1,028,338.80 | 724,288.42 | 42.0% |
| 2011-10 | 1,103,327.63 | 1,028,338.80 | 7.3% |
| 2011-11 | 1,452,112.69 | 1,103,327.63 | 31.6% |
| 2011-12 | 614,495.96 | 1,452,112.69 | -57.7% |

The -57.7% in December 2011 is the same partial-month artifact from Q1, not a real drop.
Outside of that, the swings mostly track the gift-retail seasonal pattern, dips in Jan/Feb,
climbs into Q4.

---

## Q5: First order date per customer

```sql
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
```

Returns one row per customer, 5,852 rows total. First 15 shown here, full result exports
straight from Workbench as CSV.

| customer_id | first_order_date |
|---|---|
| 12346.0 | 2009-12-14 08:34:00 |
| 12347.0 | 2010-10-31 14:20:00 |
| 12348.0 | 2010-09-27 14:59:00 |
| 12349.0 | 2010-04-29 13:20:00 |
| 12350.0 | 2011-02-02 16:01:00 |
| 12351.0 | 2010-11-29 15:23:00 |
| 12352.0 | 2010-11-12 10:20:00 |
| 12353.0 | 2010-10-27 12:44:00 |
| 12354.0 | 2011-04-21 13:11:00 |
| 12355.0 | 2010-05-21 11:59:00 |
| 12356.0 | 2010-10-11 09:42:00 |
| 12357.0 | 2010-11-16 10:05:00 |
| 12358.0 | 2009-12-08 07:59:00 |
| 12359.0 | 2009-12-05 13:32:00 |
| 12360.0 | 2010-02-22 09:32:00 |

This is the cohort assignment table, each customer's first_order_date gets truncated to a
month in Phase 4 and becomes their cohort label.

---

## Optional: cancelled revenue

```sql
SELECT
    ROUND(ABS(SUM(Quantity * Price)), 2) AS cancelled_value,
    COUNT(DISTINCT Invoice)              AS num_cancellation_invoices
FROM orders_cancellations;
```

| cancelled_value | num_cancellation_invoices |
|---|---|
| 726,611.45 | 7,410 |

This query was in `02_business_queries.sql` from the start but never actually got run and
recorded here, so it's added now. Wrapped the sum in `ABS()` since cancellation quantities are
stored as negative numbers and a plain sum would come back negative, which reads oddly next to
a label like "cancelled_value." £726,611.45 across 7,410 invoices works out to 3.6% of the £20.37M in gross revenue before
cancellations (£19.65M in `orders_clean_full` plus the cancelled amount), a reasonable return
rate for a giftware retailer and not something that needs a flag on its own.
Worth remembering this only covers product-line cancellations, cancelled postage or fee lines
were already stripped out earlier in the cleaning pipeline, see `assumptions_log.md`.
