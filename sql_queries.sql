--  Missing a LINE_ITEM_ID, this CTE partitions by ALL 23 columns to safely collapse  a 14% exact-duplicate logging bug. This surgical deduplication is critical to  prevent severe revenue inflation and protect overall KPI integrity. 
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
