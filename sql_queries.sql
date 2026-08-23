--1. Annual Performance and YoY Growth (Revenue, Orders, AOV)
WITH YearlyFinancials AS (
    -- Calculate base metrics per year
    SELECT 
        EXTRACT(YEAR FROM purchase_date) AS purchase_year,
        SUM(usd_price) AS total_revenue,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(usd_price)::numeric / NULLIF(COUNT(DISTINCT order_id), 0) AS aov
    FROM orders_final
    WHERE purchase_date IS NOT NULL
    GROUP BY 1
)
-- Format output and calculate YoY growth
SELECT 
    purchase_year AS "Year",
    
    '$' || ROUND(total_revenue / 1000000.0, 2) || 'M' AS "Revenue",
    ROUND(100.0 * (total_revenue - LAG(total_revenue) OVER(ORDER BY purchase_year)) / NULLIF(LAG(total_revenue) OVER(ORDER BY purchase_year), 0), 1) || '%' AS "Rev_YoY%",
    
    total_orders AS "Orders",
    ROUND(100.0 * (total_orders - LAG(total_orders) OVER(ORDER BY purchase_year)) / NULLIF(LAG(total_orders) OVER(ORDER BY purchase_year), 0), 1) || '%' AS "Ord_YoY%",
    
    '$' || ROUND(aov, 0) AS "AOV",
    ROUND(100.0 * (aov - LAG(aov) OVER(ORDER BY purchase_year)) / NULLIF(LAG(aov) OVER(ORDER BY purchase_year), 0), 1) || '%' AS "AOV_YoY%"
    
FROM YearlyFinancials
ORDER BY "Year";


--2.Regional AOV & MOV Comparison (2019 vs. 2022)
WITH OrderValues AS (
	-- Aggregate total spend per individual order
    SELECT 
        order_id,
        EXTRACT(YEAR FROM purchase_date) AS purchase_year,
        region,
        SUM(usd_price) AS order_value
    FROM orders_final
    WHERE EXTRACT(YEAR FROM purchase_date) IN (2019, 2022)
      AND region IS NOT NULL
    GROUP BY 1, 2, 3
),
AggregatedMetrics AS (
    -- Calculate AOV & MOV
    SELECT
        region,
        purchase_year,
        SUM(order_value)::numeric / NULLIF(COUNT(DISTINCT order_id), 0) AS aov,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_value) AS mov
    FROM OrderValues
    GROUP BY 1, 2
)
SELECT
    -- Pivot data for side-by-side yearly comparison
    region,
    '$' || ROUND(MAX(CASE WHEN purchase_year = 2019 THEN aov END)) AS "2019_AOV",
    '$' || ROUND(MAX(CASE WHEN purchase_year = 2019 THEN mov END)) AS "2019_MOV",
    '$' || ROUND(MAX(CASE WHEN purchase_year = 2022 THEN aov END)) AS "2022_AOV",
    '$' || ROUND(MAX(CASE WHEN purchase_year = 2022 THEN mov END)) AS "2022_MOV"
FROM AggregatedMetrics
GROUP BY 1
ORDER BY MAX(CASE WHEN purchase_year = 2019 THEN aov END) DESC




























--10.  Missing a LINE_ITEM_ID, this CTE partitions by ALL 23 columns to safely collapse  a 14% exact-duplicate logging bug. This surgical deduplication is critical to  prevent severe revenue inflation and protect overall KPI integrity. 
---- Deduplicating identical retries by partitioning across all columns.
-- This approach is a necessary workaround due to a missing LINE_ITEM_ID (broken granularity).
-- Creating a new deduplicated table by partitioning across all columns.
-- This approach resolves a data granularity issue, fully documented in the Issue Log (Enova_Data_and_Issue_Log).

CREATE TABLE orders_dataset_clean_no_duplicates AS
SELECT *
FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY
                USER_ID, ORDER_ID, PURCHASE_DATE, PURCHASE_MONTH_YEAR,
                SHIP_DATE, DELIVERY_DATE, REFUND_DATE, REFUNDED,
                DAYS_TO_SHIP, TRANSIT_TIME, RETURN_WINDOW,
                PRODUCT_NAME, PRODUCT_ID, USD_PRICE, LOCAL_PRICE,
                CURRENCY, PURCHASE_PLATFORM, MARKETING_CHANNEL,
                ACCOUNT_CREATION_METHOD, COUNTRY_CODE, REGION,
                LOYALTY_PROGRAM, CREATED_ON
            ORDER BY ORDER_ID
        ) as rn
    FROM orders_final
) sub
WHERE rn = 1;

ALTER TABLE orders_dataset_clean_no_duplicates DROP COLUMN rn;
