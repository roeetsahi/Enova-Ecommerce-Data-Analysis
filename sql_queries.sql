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


	
-- 3. Regional AOV vs. Global Baseline (2022 Gap Analysis)
WITH RegionalMetrics AS (
    -- total revenue and orders per region
    SELECT
        COALESCE(region, 'Unknown') AS region,
        SUM(usd_price) AS total_revenue,
        COUNT(DISTINCT order_id) AS total_orders
    FROM orders_final
    WHERE EXTRACT(YEAR FROM purchase_date) = 2022
    GROUP BY 1
),
AOV_Comparison AS (
    --  Regional AOV and Global AOV
    SELECT
        region,
        total_revenue::numeric / NULLIF(total_orders, 0) AS regional_aov,
        SUM(total_revenue) OVER()::numeric / NULLIF(SUM(total_orders) OVER(), 0) AS global_aov
    FROM RegionalMetrics
)
-- calculate the performance gap against the global average
SELECT
    region AS "Region Name",
    '$' || ROUND(regional_aov) AS "AOV 2022",
    ROUND(((regional_aov - global_aov) / NULLIF(global_aov, 0)) * 100.0, 1) || '%' AS "Gap vs Global Avg"
FROM AOV_Comparison
ORDER BY regional_aov DESC;



-- 4. Product-Level Return Rates & Financial Impact
SELECT
    product_name,
    COUNT(order_id) AS "Total Orders",
    SUM(refunded) AS "Total Returns",
    ROUND(SUM(CASE WHEN refunded = 1 THEN usd_price ELSE 0 END)) AS "USD REFUNDED($)",
    ROUND(SUM(refunded) * 100.0 / NULLIF(COUNT(order_id), 0), 2) AS "Return Rate (%)"
FROM orders_final
GROUP BY 1
ORDER BY "Return Rate (%)" DESC;



-- 5. Customer Buying Behavior: First vs. Returning Orders (Loyalty vs. non-loyalty)
WITH CustomerOrderRank AS (
	-- Rank sequential orders per customer
    SELECT 
		user_id, purchase_date, order_id, usd_price, loyalty_program,
        EXTRACT(YEAR FROM purchase_date) AS purchase_year,
        DENSE_RANK() OVER (PARTITION BY user_id ORDER BY purchase_date, order_id) as order_rank
    FROM orders_final
    WHERE purchase_date IS NOT NULL
),
YearlyLoyaltyMetrics AS (
	-- Calculate orders and AOV per year, order type, and loyalty status
    SELECT
        purchase_year,
        CASE WHEN order_rank = 1 THEN 'First Order' ELSE 'Returning Order' END AS order_type,
        loyalty_program,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(usd_price)::numeric / NULLIF(COUNT(DISTINCT order_id), 0) AS aov
    FROM CustomerOrderRank
    GROUP BY 1, 2, 3
)
-- Pivot data for direct side-by-side comparison
SELECT
    purchase_year,
    order_type,
    MAX(CASE WHEN loyalty_program = 1 THEN total_orders END) AS "Member Orders",
    MAX(CASE WHEN loyalty_program = 0 THEN total_orders END) AS "Guest Orders",
    '$' || ROUND(MAX(CASE WHEN loyalty_program = 1 THEN aov END)) AS "Member AOV",
    '$' || ROUND(MAX(CASE WHEN loyalty_program = 0 THEN aov END)) AS "Guest AOV"
FROM YearlyLoyaltyMetrics
GROUP BY 1, 2
ORDER BY 1, 2;



-- 6.Top 3 Peak Months by Marketing Channel
WITH ChannelMonthlyRevenue AS (
    -- Calculate and rank monthly revenue per marketing channel
    SELECT 
        marketing_channel,
        TO_CHAR(purchase_date, 'Mon-YYYY') AS month_label,
        SUM(usd_price) AS total_revenue,
        DENSE_RANK() OVER(PARTITION BY marketing_channel ORDER BY SUM(usd_price) DESC) AS revenue_rank
    FROM orders_final
    WHERE marketing_channel IS NOT NULL 
      AND purchase_date IS NOT NULL
    GROUP BY 1, 2
)
-- Pivot the top 3 months into a consolidated text format
SELECT
    marketing_channel AS "Marketing Channel",
    MAX(CASE WHEN revenue_rank = 1 THEN month_label || ' : $' || ROUND(total_revenue / 1000.0, 1) || 'K' END) AS "1st Peak Month",
    MAX(CASE WHEN revenue_rank = 2 THEN month_label || ' : $' || ROUND(total_revenue / 1000.0, 1) || 'K' END) AS "2nd Peak Month",
    MAX(CASE WHEN revenue_rank = 3 THEN month_label || ' : $' || ROUND(total_revenue / 1000.0, 1) || 'K' END) AS "3rd Peak Month"
FROM ChannelMonthlyRevenue
GROUP BY 1
ORDER BY 1;



-- 7. Monthly Revenue Share (Loyalty Members vs. Non-Members) Throughout All Years
WITH MonthlyLoyaltyRev AS (
	-- Aggregate revenue per month and loyalty status
    SELECT
        DATE_TRUNC('month', purchase_date) AS month_year,
        loyalty_program,
        SUM(usd_price) AS total_revenue
    FROM orders_final
    WHERE purchase_date IS NOT NULL
    GROUP BY 1, 2
),
MonthlyLoyaltyShare AS (
	-- percentage share of revenue per month
    SELECT
        month_year,
        loyalty_program,
        100.0 * total_revenue / NULLIF(SUM(total_revenue) OVER (PARTITION BY month_year), 0) AS rev_share
    FROM MonthlyLoyaltyRev
)
--Pivoting the results
SELECT
    TO_CHAR(month_year, 'Mon-YYYY') AS "Month",
    ROUND(MAX(CASE WHEN loyalty_program = 1 THEN rev_share END), 2) || '%' AS "Loyalty Share",
    ROUND(MAX(CASE WHEN loyalty_program = 0 THEN rev_share END), 2) || '%' AS "Non-Loyalty Share"
FROM MonthlyLoyaltyShare
GROUP BY month_year
ORDER BY month_year ASC;



-- 8. Data Governance & Architecture: Creating a new deduplicated table by applying strict row-level partitioning across all columns.
-- Note: Due to granularity limitations (lack of LINE_ITEM_ID / QUANTITY), this full-column partition safely removes logging duplicates without dropping valid multi-item orders.
-- (For a full technical and business explanation, see the Data Quality Issue Log).

CREATE TABLE orders_final AS
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
    FROM orders -- The original raw table.
) sub
WHERE rn = 1;

ALTER TABLE orders_final DROP COLUMN rn;
