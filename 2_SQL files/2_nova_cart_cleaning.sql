

-- =====================================================================
-- NovaCart — Fact Table Cleaning
-- Cleans fact_campaigns and standardizes shared dimension values.
-- Run after 01_profiling.sql, before 03_campaign_performance.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. record_date: standardize inconsistent date formats
-- ---------------------------------------------------------------------
-- Source data mixes multiple date formats (M/D/YYYY, DD-Mon-YY, DD-MM-YYYY),
-- plus blank/invalid strings ('', '----'). Each is parsed into a proper
-- DATE column; anything unrecognized is set to NULL rather than guessed.

SELECT DISTINCT
    REGEXP_REPLACE(record_date, '[0-9]', 'X', 'g') AS date_pattern
FROM fact_campaigns;

ALTER TABLE fact_campaigns
ADD COLUMN record_date_clean date;

UPDATE fact_campaigns
SET record_date_clean = CASE
    -- M/D/YYYY, e.g. 7/10/2023 or 11/9/2019
    WHEN record_date ~ '^\d{1,2}/\d{1,2}/\d{4}$'
        THEN to_date(record_date, 'FMMM/FMDD/YYYY')

    -- DD-Mon-YY, e.g. 26-Nov-21 or 7-Aug-19
    WHEN record_date ~ '^\d{1,2}-[A-Za-z]{3}-\d{2}$'
        THEN to_date(regexp_replace(record_date, '-(\d{2})$', '-20\1'), 'FMDD-Mon-YYYY')

    -- DD-MM-YYYY, e.g. 26-06-2019
    WHEN record_date ~ '^\d{2}-\d{2}-\d{4}$'
        THEN to_date(record_date, 'DD-MM-YYYY')

    ELSE NULL  -- catches '', '----', and any unrecognized format
END;

-- Validation: confirm every remaining NULL is a genuinely blank/invalid
-- source value, not a date format the CASE statement missed.
SELECT record_date, count(*)
FROM fact_campaigns
WHERE record_date_clean IS NULL
  AND record_date NOT IN ('', '----')
GROUP BY record_date;

-- Replace the raw column with the cleaned one.
ALTER TABLE fact_campaigns DROP COLUMN record_date;
ALTER TABLE fact_campaigns RENAME COLUMN record_date_clean TO record_date;

-- ---------------------------------------------------------------------
-- 2. device: normalize casing/whitespace
-- ---------------------------------------------------------------------
-- Raw values vary in capitalization and spacing (e.g. 'mobile', 'Mobile ',
-- 'MOBILE'). Trimmed and title-cased to a consistent form.

UPDATE fact_campaigns
SET device = trim(initcap(device));

SELECT DISTINCT device FROM fact_campaigns;

-- ---------------------------------------------------------------------
-- 3. country: normalize and map aliases (fact_campaigns + dim_customer)
-- ---------------------------------------------------------------------
-- Raw country values have inconsistent casing/punctuation and multiple
-- aliases for the same country (e.g. 'US', 'USA', 'United States').
-- Standardized to a single canonical name per country in both tables.

ALTER TABLE fact_campaigns ADD COLUMN country_clean VARCHAR(255);

UPDATE fact_campaigns
SET country_clean = trim(initcap(replace(country, '.', '')));

UPDATE fact_campaigns
SET country_clean = CASE
        WHEN country_clean = 'Uk'  THEN 'United Kingdom'
        WHEN country_clean = 'Us'  THEN 'United States'
        WHEN country_clean = 'Usa' THEN 'United States'
        WHEN country_clean = 'Uae' THEN 'United Arab Emirates'
        ELSE country_clean
    END;

SELECT DISTINCT country_clean FROM fact_campaigns;

ALTER TABLE fact_campaigns DROP COLUMN country;
ALTER TABLE fact_campaigns RENAME COLUMN country_clean TO country;

-- Repeat the same normalization for dim_customer, so country values are
-- consistent across both tables (needed for any customer-level joins).
ALTER TABLE dim_customer ADD COLUMN country_clean VARCHAR(255);

UPDATE dim_customer
SET country_clean = trim(initcap(replace(country, '.', '')));

UPDATE dim_customer
SET country_clean = CASE
        WHEN country_clean = 'Us' OR country_clean = 'Usa' THEN 'United States'
        WHEN country_clean = 'Uae' THEN 'United Arab Emirates'
        WHEN country_clean = 'Uk'  THEN 'United Kingdom'
        ELSE country_clean
    END;

ALTER TABLE dim_customer DROP COLUMN country;
ALTER TABLE dim_customer RENAME COLUMN country_clean TO country;

-- Validation: confirm both tables now share the same set of country values.
SELECT DISTINCT country FROM fact_campaigns
EXCEPT
SELECT DISTINCT country FROM dim_customer;

-- city column checked and required no cleaning.
SELECT DISTINCT city FROM dim_customer;

-- ---------------------------------------------------------------------
-- 4. revenue: resolve NULLs based on conversion behavior
-- ---------------------------------------------------------------------
-- NULL revenue was investigated as two distinct cases rather than one:
--   - 6,001 rows: NULL revenue + 0 conversions -> no conversion occurred,
--     so revenue is genuinely zero. Filled with 0.
--   - 4,948 rows: NULL revenue + conversions > 0 -> a conversion happened
--     but its revenue was never recorded. This is a real data gap, not a
--     zero, and is intentionally left NULL rather than imputed.

UPDATE fact_campaigns
SET revenue = 0
WHERE revenue IS NULL AND conversions = 0;

-- ---------------------------------------------------------------------
-- 5. Business rule violations: funnel logic (impressions -> clicks -> conversions)
-- ---------------------------------------------------------------------
-- Rows violating the expected funnel (clicks > impressions, or
-- conversions > clicks) are flagged rather than deleted, preserving the
-- record while marking it as unreliable for funnel-based analysis.

ALTER TABLE fact_campaigns ADD COLUMN invalid_clicks boolean;

UPDATE fact_campaigns
SET invalid_clicks = CASE
        WHEN clicks > impressions THEN true
        ELSE false
    END;

SELECT count(*) FROM fact_campaigns WHERE invalid_clicks IS true;

ALTER TABLE fact_campaigns ADD COLUMN invalid_conversion boolean;

UPDATE fact_campaigns
SET invalid_conversion = CASE
        WHEN conversions > clicks THEN true
        ELSE false
    END;

SELECT count(*) FROM fact_campaigns WHERE invalid_conversion IS true;

-- ---------------------------------------------------------------------
-- 6. dim_campaign: flag invalid date ranges (end_date < start_date)
-- ---------------------------------------------------------------------
-- 103 campaigns (~2% of dim_campaign) have an end_date before their
-- start_date. Flagged with a boolean column rather than corrected or
-- removed, so downstream analysis can choose to include or exclude them.

SELECT
    count(*),
    count(*) * 100.0 / (SELECT count(*) FROM dim_campaign) AS pct_affected
FROM dim_campaign
WHERE end_date < start_date;

ALTER TABLE dim_campaign ADD COLUMN invalid_date boolean;

UPDATE dim_campaign
SET invalid_date = CASE
        WHEN start_date > end_date THEN true
        ELSE false
    END;

-- Validation
SELECT start_date, end_date, invalid_date
FROM dim_campaign
WHERE start_date > end_date;

-- ---------------------------------------------------------------------
-- 7. fact_campaigns: flag orphaned campaign_id (no match in dim_campaign)
-- ---------------------------------------------------------------------
-- 3,321 fact rows (2,379 unique campaign_id values, ~1.5% of fact_campaigns)
-- reference a campaign_id with no matching row in dim_campaign. Flagged
-- rather than dropped, since these rows still carry real revenue/spend
-- that would otherwise be silently lost from totals.

SELECT
    count(*) AS invalid_fact_id,
    round(count(*) * 100.0 / (SELECT count(*) FROM fact_campaigns), 2) AS percentage
FROM fact_campaigns AS f
LEFT JOIN dim_campaign AS p ON p.campaign_id = f.campaign_id
WHERE p.campaign_id IS NULL;

SELECT count(DISTINCT campaign_id)
FROM fact_campaigns
WHERE campaign_id NOT IN (SELECT campaign_id FROM dim_campaign);

SELECT
    campaign_id,
    count(*) AS missing_rows,
    sum(revenue) AS total_revenue,
    sum(spendings) AS total_cost
FROM fact_campaigns
WHERE campaign_id NOT IN (SELECT campaign_id FROM dim_campaign)
GROUP BY campaign_id
ORDER BY total_cost DESC;

ALTER TABLE fact_campaigns ADD COLUMN id_flag boolean;

UPDATE fact_campaigns AS f
SET id_flag = true
WHERE NOT EXISTS (
    SELECT campaign_id FROM dim_campaign AS c
    WHERE c.campaign_id = f.campaign_id
);

UPDATE fact_campaigns
SET id_flag = false
WHERE id_flag IS NULL;

-- ---------------------------------------------------------------------
-- 8. Verification: confirm record_date cleaning against source data
-- ---------------------------------------------------------------------
-- A backup table (loaded from the original source CSV) is used to verify
-- that the cleaned record_date column matches the original source values
-- with no unintended data loss during the cleaning process above.

CREATE TABLE fact_campaigns_backup (
    fact_id      int,
    campaign_id  int,
    customer_id  int,
    channel_id   int,
    record_date  text,
    device       varchar(50),
    country      varchar(50),
    impressions  numeric,
    clicks       numeric,
    conversions  numeric,
    spendings    decimal,
    revenue      decimal
);

-- Path is local to the original development environment; update before
-- re-running.
COPY fact_campaigns_backup
FROM 'G:/Portfolio/marketing campaign project/fact_campaign_performance.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

-- Verification query: any row where the cleaned table lost a record_date
-- value that exists in the original backup would appear here.
SELECT DISTINCT f.fact_id, f.record_date, b.record_date
FROM fact_campaigns AS f
LEFT JOIN fact_campaigns_backup AS b ON b.fact_id = f.fact_id
WHERE f.record_date IS NOT NULL AND b.record_date IS NULL;

-- Result: no rows returned — record_date cleaning preserved all source data.