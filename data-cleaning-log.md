# Data Cleaning & Preparation Log

Below is a summary of the key data transformations, categorized by their business and technical impact:

## 1. Data Standardization & Formatting
* **Data Type Corrections:** Converted `USER_ID`, `ORDER_ID`, and `PRODUCT_ID` to Text/String format to prevent erroneous numerical aggregations.
* **Timestamp Resolution:** Renamed `_TS` columns (e.g., `PURCHASE_TS` to `PURCHASE_DATE`) as they lacked hourly granularity, and standardized the format to MM/DD/YYYY across all dates.
* **Text Consistency:** Standardized inconsistent naming conventions in `PRODUCT_NAME` (e.g., uniforming "27in 4K gaming monitor") and `REGION` (mapping "North America" to "NA").

## 2. Critical Data Integrity & Architecture Fixes
* **Deduplication:** Applied strict row-level deduplication using a SQL CTE and `ROW_NUMBER()` window function, partitioned by all columns to safely collapse identical logging retries. *(Note: This aggressive partitioning was required to resolve a broken granularity issue detailed in the Excel Issue Log Below).* 
* **SCD Loyalty Ambiguity (Look-Ahead Bias Prevention):** Addressed users with fluctuating loyalty statuses by adopting a Dual-Attribution approach. Financial metrics were attributed to the point-in-time status, while behavioral metrics utilized an "Ever-Member" cohort logic to preserve tracking integrity.
* **Account Creation Anomalies:** Identified users with overwritten `CREATED_ON` timestamps. Retained original values but excluded this field from time-based analyses to prevent misleading Lifetime Value (LTV) and Cohort Retention metrics.

## 3. Handling Missing Data & Tracking Gaps
* **Attribution Consolidation:** Consolidated missing records in `MARKETING_CHANNEL` and `ACCOUNT_CREATION_METHOD` into a unified 'UNKNOWN' category to preserve ground-truth tracking gaps. 
* **Geographic Enrichment:** Addressed nonsensical country codes by mapping regional abbreviations (e.g., AP -> APAC). Enriched missing `REGION` values via manual ISO standard lookups (e.g., BJ -> EMEA, BM -> NA) to ensure 100% geographic reporting coverage.

## 4. Data Augmentation & Feature Engineering 
To facilitate advanced pivot analysis and dashboard visualizations, several core dimensions were engineered:
* **Binary Classification:** Created a boolean `REFUNDED` flag (1/0) based on the presence of a refund date, streamlining the calculation of refund rates across different operational dimensions.
* **Operational KPIs:** Engineered new duration metrics including `DAYS_TO_SHIP` (Ship Date - Purchase Date) and `RETURN_WINDOW` (Refund Date - Delivery Date) to allow for deeper operational analysis.
* **Dimensional Lookups:** Enriched the core transactional dataset by importing complete `REGION` and `COUNTRY_NAME` dimensions via XLOOKUP from mapping tables.

---

### Deep-Dive Issue Log & Dataset

* **[Data Quality Issue Log (Excel)](./Enova_Issue_Log.xlsx)** - An in-depth breakdown of anomalies, magnitude percentages, unresolvable issues, and cross-functional team escalations.
* **[Enova Raw and Cleaned Data (XLSB)](./Enova_Raw_and_Cleaned_Data.xlsb)** - Contains the original RAW data alongside the final, cleaned dataset ready for analysis.
