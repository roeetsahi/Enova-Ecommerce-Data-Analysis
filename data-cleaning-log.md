# Data Cleaning & Preparation Log

Below is a summary of the key data transformations, categorized by their business and technical impact:

## 1. Data Standardization & Formatting
* **Data Type Corrections:** Converted `USER_ID`, `ORDER_ID`, and `PRODUCT_ID` to Text/String format to prevent erroneous numerical aggregations.
* **Timestamp Resolution:** Renamed `_TS` columns (e.g., `PURCHASE_TS` to `PURCHASE_DATE`) as they lacked hourly granularity, and standardized the format to MM/DD/YYYY across all dates.
* **Text Consistency:** Standardized inconsistent naming conventions in `PRODUCT_NAME` (e.g., uniforming "27in 4K gaming monitor") and `REGION` (mapping "North America" to "NA").

## 2. Data Quality Findings & Analytical Limitations
* **Duplicate & Grain Assessment:** Identified 15,196 exact duplicate-like records (14.05% of the dataset). Because the source data lacks both a LINE_ITEM_ID and QUANTITY field, identical rows cannot be reliably distinguished from legitimate repeated-item quantities. No records were removed from the analytical dataset. A SQL ROW_NUMBER() diagnostic was used to isolate duplicate candidates for source-system validation before any production deduplication. 
* **Loyalty Status Attribution (SCD Limitation):** Mixed loyalty values were observed across transactions for 1,026 users. Financial reporting used the loyalty status recorded on each transaction, while behavioral comparisons used a separately defined retrospective Ever-Member cohort. The two analytical views were kept separate because no effective-dated membership history (e.g., SCD Type 2) was available.
* **Account Creation Date Integrity:** dentified users with multiple conflicting CREATED_ON values, indicating that the field does not behave as a reliable immutable account-creation timestamp. The affected records were retained to avoid biasing otherwise valid transactional analysis. However, the unreliable timestamp prevented reliable customer-tenure analyses such as time-to-conversion, Lifetime Value (LTV), and cohort retention.


## 3. Handling Missing Data & Tracking Gaps
* **Attribution Consolidation:** Consolidated missing records in `MARKETING_CHANNEL` and `ACCOUNT_CREATION_METHOD` into a unified 'UNKNOWN' category to preserve ground-truth tracking gaps. 
* **Geographic Enrichment:** Addressed nonsensical country codes by mapping regional abbreviations (e.g., AP -> APAC). Enriched missing `REGION` values via manual ISO standard lookups (e.g., BJ -> EMEA, BM -> NA) to ensure 100% geographic reporting coverage.

## 4. Data Augmentation & Feature Engineering 
To facilitate advanced pivot analysis and dashboard visualizations, several core dimensions were engineered:
* **Binary Classification:** Created a boolean `REFUNDED` flag (1/0) based on the presence of a refund date, streamlining the calculation of refund rates across different operational dimensions.
* **Operational Duration Features:** Engineered DAYS_TO_SHIP and RETURN_WINDOW for exploratory analysis. Implausible values were identified in a small share of DAYS_TO_SHIP and ~5% of RETURN_WINDOW records. As operational timing analysis was outside the stakeholder scope, these metrics were not used in final findings pending source validation.
* **Dimensional Lookups:** Enriched the core transactional dataset by importing complete `REGION` and `COUNTRY_NAME` dimensions via XLOOKUP from mapping tables.

---

### Deep-Dive Issue Log & Dataset

* **[Data Quality Issue Log (Excel)](./Enova_Issue_Log.xlsx)** - A detailed record of data anomalies, issue magnitude, analytical impact, resolution decisions, and recommended production owners and escalation paths.
* **[Enova Raw and Cleaned Data (XLSB)](./Enova_Raw_and_Cleaned_Data.xlsb)** - Contains the original RAW data alongside the final, cleaned dataset ready for analysis.
