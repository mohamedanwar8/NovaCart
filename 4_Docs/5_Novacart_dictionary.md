# NovaCart Data Dictionary

---

## 1. Source files

| File | Rows | Description |
|---|---:|---|
| `dim_channel.csv` | 15 | Marketing channel lookup |
| `dim_date.csv` | 2,192 | Calendar dimension, 2019-01-01 to 2024-12-31 |
| `dim_customer.csv` | 5,150 | Customer demographics & segmentation |
| `dim_campaign.csv` | 5,100 | Campaign metadata |
| `fact_campaign_performance.csv` | 220,375 | Grain: one row per campaign/customer touchpoint |

---

## 2. Derived analysis table

| Table | Rows | Description |
|---|---:|---|
| `novacart_campaigns` | 1,195 | Grain: one row per campaign. Limited to campaigns with `end_date` in the last 3 years. Built from `dim_campaign` + `fact_campaigns` — see `sql/03_campaign_performance.sql`. |

---

## 3. Column reference

### 3.1 dim_channel

| Column | Notes |
|---|---|
| `channel_id` | PK |
| `channel_name` | |
| `channel_subtype` | |
| `channel_category` | Paid / Owned / Organic / Partner |

### 3.2 dim_date

| Column | Notes |
|---|---|
| `date_id` | PK |
| `full_date`, `day`, `month`, `month_name`, `quarter`, `year` | |
| `day_of_week`, `is_weekend` | |
| | Not used in the final `novacart_campaigns` build — the analysis table is fully aggregated to one row per campaign, so day-level date joins weren't needed for this business question. |

### 3.3 dim_customer

| Column | Notes |
|---|---|
| `customer_id` | PK, not unique after duplicate injection |
| `first_name`, `last_name`, `email` | |
| `age`, `gender`, `country`, `city` | |
| `segment` | New / Returning / VIP / At-Risk / Churned |
| `signup_date`, `preferred_device` | |
| | Not used in the final model — this analysis answers a campaign-level budget question, not a customer-segmentation one. |

### 3.4 dim_campaign

| Column | Notes |
|---|---|
| `campaign_id` | PK, not unique after duplicate injection |
| `campaign_name`, `campaign_manager` | |
| `channel_id` | FK → dim_channel |
| `start_date`, `end_date`, `budget` | |
| `campaign_type` | Awareness / Acquisition / Conversion / Retention / Brand |
| `target_segment`, `target_country` | |
| `invalid_date` | Boolean flag, `true` where `start_date > end_date` (~103 campaigns, ~2%). See §4 — flagged but **not excluded** from `novacart_campaigns`. |

### 3.5 fact_campaigns

| Column | Notes |
|---|---|
| `fact_id` | PK |
| `campaign_id` | FK — some values have no match in `dim_campaign` (see `id_flag`) |
| `customer_id` | FK, some invalid/missing |
| `channel_id` | FK |
| `record_date` | Cleaned to a proper `date` type (originally a raw string in mixed formats) |
| `device`, `country` | Normalized (casing, whitespace, aliasing — see `sql/02_cleaning.sql`) |
| `impressions`, `clicks`, `conversions`, `spendings`, `revenue` | |
| `invalid_clicks` | Boolean flag, `true` where `clicks > impressions`. Flagged but **not excluded** from `novacart_campaigns` — see §4. |
| `invalid_conversion` | Boolean flag, `true` where `conversions > clicks`. Flagged but **not excluded** — see §4. |
| `id_flag` | Boolean flag, `true` where `campaign_id` has no match in `dim_campaign` (~3,321 rows, ~1.5%). These rows are still included in `novacart_campaigns` aggregates for `campaign_id` values that *do* exist in `dim_campaign`; rows with a genuinely unmatched `campaign_id` are naturally excluded by the join in step 2 below, since there's no `dim_campaign` row to join to. |

### 3.6 novacart_campaigns *(derived — the table Power BI connects to)*

**Identity**

| Column | Notes |
|---|---|
| `campaign_id` | PK, FK → `dim_campaign.campaign_id`. Confirmed unique (1,195 rows, 1,195 distinct `campaign_id` values) |
| `campaign_name`, `campaign_manager`, `campaign_type` | From `dim_campaign` |
| `budget`, `start_date`, `end_date` | From `dim_campaign` |
| `duration` | `end_date - start_date` |

**Aggregated metrics** *(summed over all matching `fact_campaigns` rows per campaign, no date-range restriction on the underlying activity — only the campaign's `end_date` is filtered to the last 3 years)*

| Column | Notes |
|---|---|
| `total_revenue`, `total_cost` | `SUM(revenue)`, `SUM(spendings)` |
| `total_impressions`, `total_clicks`, `total_conversion` | `SUM()` of each |

**Derived ratios** *(calculated from the summed totals above, not per-row — avoids the unweighted-average error of averaging a per-row ratio column)*

| Column | Formula | Notes |
|---|---|---|
| `roas` | `total_revenue / total_cost` | `NULLIF`-protected against division by zero |
| `conversion_rate` | `(total_conversion / total_clicks) * 100` | `NULLIF`-protected |
| `cpr` | `total_cost / total_conversion` | cost per result, `NULLIF`-protected |

**Segmentation (relative to own `campaign_type`)**

| Column | Notes |
|---|---|
| `median_roas`, `median_cost` | Calculated **within each campaign's own `campaign_type`** (`PERCENTILE_CONT(0.5)` grouped by `campaign_type`), not dataset-wide. Same value repeated across every row of that type |
| `scale_efficiency` | One of: *High scale & High efficiency* / *Low scale & High efficiency* / *High scale & Low efficiency* / *Low scale & Low efficiency*. "Scale" = `total_cost` vs. `median_cost`; "efficiency" = `roas` vs. `median_roas` |

---

## 4. Known limitations (documented, not silently excluded)

These reflect the actual state of the final query — flags exist in the source data but are **not** used to filter `novacart_campaigns`. Documented here for transparency rather than treated as resolved:

- **Invalid funnel activity** — rows flagged `invalid_clicks` (clicks > impressions) or `invalid_conversion` (conversions > clicks) are still included in the `SUM()` aggregations. A future iteration could exclude these rows before aggregating, or aggregate with and without them to quantify the impact.
- **Invalid campaign dates** — the ~103 campaigns (~2%) flagged `invalid_date` in `dim_campaign` (end_date before start_date) are not excluded from `novacart_campaigns`. Their `duration` value would be negative, which should be treated with caution if used in any visual.
- **Orphaned fact rows** — fact rows with a `campaign_id` not present in `dim_campaign` cannot appear in `novacart_campaigns` at all, since the `campaigns` CTE is built by joining `campaign_totals` to `dim_campaign`. This means revenue/spend from those ~3,321 orphaned rows (~1.5% of `fact_campaigns`) is silently absent from any campaign total — a known, quantifiable gap rather than a hidden one.
- **Scope** — `novacart_campaigns` only includes campaigns with `end_date` in the last 3 years; older campaigns are excluded entirely from this analysis.

---

## 5. Outlier handling (applied in Power BI, not in this table)

`novacart_campaigns` itself contains all 1,195 rows with no outlier removal. Outlier filtering is applied at the Power BI visual/measure level, not baked into this table:

- `roas` values ≤ 0 or > 6.4 (the 75th percentile) are excluded from dashboard visuals — a sharp jump between the 75th and 80th percentile (6.4 → 33) indicated these are likely driven by near-zero-spend campaigns producing mathematically unstable ratios, not genuine performance
- `total_cost` values > 10,000 (the 95th percentile) are excluded from the scatter chart for readability — this distribution is smoothly right-skewed with no discontinuity, so this is a visualization choice, not an anomaly correction