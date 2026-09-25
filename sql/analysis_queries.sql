-- Olist E-Commerce Analysis
-- SQL Server
--
-- Curated analytical queries used to investigate:
-- sales, customers, products, delivery performance
-- and geographic differences in customer spending.

-- ============================================
-- 1. Delivery Performance
-- ============================================
-- Average delivery time by customer state

SELECT
    c.customer_state,
    AVG(
        CAST(
            DATEDIFF(
                day,
                o.order_purchase_timestamp,
                o.order_delivered_customer_date
            ) AS decimal(10,2)
        )
    ) AS avg_delivery_days
FROM olist_orders_dataset AS o
JOIN olist_customers_dataset AS c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days;


-- ============================================
-- 2. Delivery Status & Customer Satisfaction
-- ============================================

-- Compare review scores for orders delivered early,
-- on time or late relative to the estimated delivery date.

WITH delivery_status AS (
    SELECT
        o.order_id,
        CASE
            WHEN o.order_delivered_customer_date IS NULL
                THEN 'Not delivered'
            WHEN CAST(o.order_delivered_customer_date AS date)
                 < CAST(o.order_estimated_delivery_date AS date)
                THEN 'Early'
            WHEN CAST(o.order_delivered_customer_date AS date)
                 > CAST(o.order_estimated_delivery_date AS date)
                THEN 'Late'
            ELSE 'On time'
        END AS delivery_status
    FROM olist_orders_dataset AS o
)
SELECT
    ds.delivery_status,
    COUNT(DISTINCT ds.order_id) AS order_count,
    AVG(CAST(r.review_score AS decimal(3,2))) AS avg_review_score
FROM delivery_status AS ds
JOIN olist_order_reviews_dataset AS r
    ON ds.order_id = r.order_id
WHERE ds.delivery_status <> 'Not delivered'
GROUP BY ds.delivery_status
ORDER BY avg_review_score DESC;


-- ============================================
-- 3. Product Category Performance
-- ============================================

-- Revenue and order-item volume by product category.

SELECT
    p.product_category_name,
    SUM(oi.price) AS total_revenue,
    COUNT(*) AS item_count,
    AVG(oi.price) AS avg_item_price
FROM olist_order_items_dataset AS oi
JOIN olist_products_dataset AS p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_revenue DESC;


-- ============================================
-- 4. Revenue After Freight
-- ============================================

-- Compare category revenue after subtracting freight costs.
-- This should not be interpreted as profit because other
-- operating costs are not available in the dataset.

SELECT
    p.product_category_name,
    SUM(oi.price) AS gross_revenue,
    SUM(oi.freight_value) AS freight_cost,
    SUM(oi.price) - SUM(oi.freight_value) AS revenue_after_freight
FROM olist_order_items_dataset AS oi
JOIN olist_products_dataset AS p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY revenue_after_freight DESC;


-- ============================================
-- 5. Customer Purchase Frequency
-- ============================================

-- Classify customers according to the number of orders placed.

WITH customer_orders AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS order_count
    FROM olist_orders_dataset
    GROUP BY customer_unique_id
)
SELECT
    CASE
        WHEN order_count > 1 THEN 'Repeat'
        ELSE 'One-time'
    END AS customer_type,
    COUNT(*) AS customer_count
FROM customer_orders
GROUP BY
    CASE
        WHEN order_count > 1 THEN 'Repeat'
        ELSE 'One-time'
    END
ORDER BY customer_count DESC;


-- ============================================
-- 6. Customer Value
-- ============================================

-- Compare total customer spend between one-time
-- and repeat customers.

WITH customer_orders AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS order_count
    FROM olist_orders_dataset
    GROUP BY customer_unique_id
),
customer_spend AS (
    SELECT
        c.customer_unique_id,
        co.order_count,
        SUM(oi.price) AS total_spend
    FROM olist_customers_dataset AS c
    JOIN customer_orders AS co
        ON c.customer_unique_id = co.customer_unique_id
    JOIN olist_orders_dataset AS o
        ON c.customer_id = o.customer_id
    JOIN olist_order_items_dataset AS oi
        ON o.order_id = oi.order_id
    GROUP BY
        c.customer_unique_id,
        co.order_count
)
SELECT
    CASE
        WHEN order_count > 1 THEN 'Repeat'
        ELSE 'One-time'
    END AS customer_type,
    COUNT(*) AS customer_count,
    AVG(total_spend) AS avg_total_spend
FROM customer_spend
GROUP BY
    CASE
        WHEN order_count > 1 THEN 'Repeat'
        ELSE 'One-time'
    END
ORDER BY avg_total_spend DESC;


-- ============================================
-- 7. Average Customer Spend by State
-- ============================================

-- Compare average customer spend across Brazilian states.

SELECT
    c.customer_state,
    (
        SUM(oi.price) + SUM(oi.freight_value)
    ) / COUNT(DISTINCT c.customer_unique_id) AS avg_customer_spend
FROM olist_customers_dataset AS c
JOIN olist_orders_dataset AS o
    ON c.customer_id = o.customer_id
JOIN olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY avg_customer_spend DESC;


-- ============================================
-- 8. Orders per Customer by State
-- ============================================

-- Examine whether geographic differences in spending
-- are primarily associated with order frequency.

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) * 1.0
        / COUNT(DISTINCT c.customer_unique_id) AS orders_per_customer
FROM olist_customers_dataset AS c
JOIN olist_orders_dataset AS o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_state
ORDER BY orders_per_customer DESC;


-- ============================================
-- 9. Data Quality Check
-- ============================================

-- Identify orders that do not have matching order-item records.

SELECT
    COUNT(*) AS orders_without_items
FROM olist_orders_dataset AS o
LEFT JOIN olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;
