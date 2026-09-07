| File                              | Rows                   | Description |
|---                                |---:                    |---|
| `dim_channel.csv`                 | 15                     | Marketing channel lookup |
| `dim_date.csv`                    | 2,192                  | Calendar dimension, 2019-01-01 to 2024-12-31 |
| `dim_customer.csv`                | 5,150                  | Customer demographics & segmentation |
| `dim_campaign.csv`                | 5,100                  | Campaign metadata |
| `fact_campaign_performance.csv`   | 220,375                | Grain: one row per campaign/customer touchpoint |




## Column reference

### dim_channel
- `channel_id` (PK), `channel_name`, `channel_subtype`, `channel_category` (Paid / Owned / Organic / Partner)

### dim_date
- `date_id` (PK), `full_date`, `day`, `month`, `month_name`, `quarter`, `year`, `day_of_week`, `is_weekend`

### dim_customer
- `customer_id` (PK, not unique after duplicate injection), `first_name`, `last_name`, `email`,
  `age`, `gender`, `country`, `city`, `segment` (New/Returning/VIP/At-Risk/Churned),
  `signup_date`, `preferred_device`

### dim_campaign
- `campaign_id` (PK, not unique after duplicate injection), `campaign_name`, `channel_id` (FK),
  `campaign_manager`, `start_date`, `end_date`, `budget`, `campaign_type`
  (Awareness/Acquisition/Conversion/Retention/Brand), `target_segment`, `target_country`

### fact_campaign_performance
- `fact_id` (PK), `campaign_id` (FK, some invalid), `customer_id` (FK, some invalid/missing),
  `channel_id` (FK), `record_date` (raw string, mixed formats), `device`, `country`,
  `impressions`, `clicks`, `conversions`, `spend`, `revenue`



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
| `novacart_campaigns` | 74,448 *(confirm exact count from your final run)* | Grain: one row per campaign. Trailing 3-year window, cleaned and classified into performance quadrants relative to each campaign's own `campaign_type`. Built from `dim_campaign` + `fact_campaign_performance` via the Phase 6 SQL pipeline (`01_sql/novacart_campaigns.sql`). |

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

### 3.3 dim_customer

| Column | Notes |
|---|---|
| `customer_id` | PK, not unique after duplicate injection |
| `first_name`, `last_name`, `email` | |
| `age`, `gender`, `country`, `city` | |
| `segment` | New / Returning / VIP / At-Risk / Churned |
| `signup_date`, `preferred_device` | |

### 3.4 dim_campaign

| Column | Notes |
|---|---|
| `campaign_id` | PK, not unique after duplicate injection |
| `campaign_name`, `campaign_manager` | |
| `channel_id` | FK → dim_channel |
| `start_date`, `end_date`, `budget` | |
| `campaign_type` | Awareness / Acquisition / Conversion / Retention / Brand |
| `target_segment`, `target_country` | |

### 3.5 fact_campaign_performance

| Column | Notes |
|---|---|
| `fact_id` | PK |
| `campaign_id` | FK, some invalid |
| `customer_id` | FK, some invalid/missing |
| `channel_id` | FK |
| `record_date` | raw string, mixed formats |
| `device`, `country` | |
| `impressions`, `clicks`, `conversions`, `spend`, `revenue` | |

### 3.6 novacart_campaigns *(derived — fact table for the dashboard)*

**Identity & join key**

| Column | Notes |
|---|---|
| `campaign_id` | PK, FK → `dim_campaign.campaign_id`. Join key for bringing in campaign name, manager, country, and channel via the Power BI data model |
| `campaign_type` | Awareness / Brand / Acquisition / Conversion / Retention. Also the segmentation key used to compute type-specific medians |

**Aggregated metrics** *(summed over the trailing 3-year window, per campaign)*

| Column | Notes |
|---|---|
| `total_impressions`, `total_clicks`, `total_conversion` | |
| `total_cost`, `total_revenue` | |

**Derived ratios**

| Column | Formula | Notes |
|---|---|---|
| `conversion_rate` | `total_conversion / total_clicks * 100` | rounded to 2 decimals |
| `cpr` | `total_cost / total_conversion` | cost per result, rounded to 2 decimals |
| `roas` | `total_revenue / total_cost` | return on ad spend, rounded to 2 decimals |

**Segmentation (relative to own campaign_type)**

| Column | Notes |
|---|---|
| `median_roas`, `median_cost` | Median ROAS/Cost calculated **within the campaign's own `campaign_type`**, not dataset-wide. Same value repeated across all rows of that type |
| `efficiency_flag` | High Efficiency / Low Efficiency — `roas` vs. `median_roas` |
| `scale_flag` | High Scale / Low Scale — `total_cost` vs. `median_cost` |
| `quadrant_label` | Star / Hidden Gem / Money Pit / Low Priority — combines `efficiency_flag` + `scale_flag` |

**Planned additions**

| Column | Status |
|---|---|
| `recommended_action` | To be added at presentation stage — Scale further / New budget candidate / Review or cut / Deprioritize |
| `trend_slope`, `trend_direction` | Deferred to Power BI — direction of ROAS over time, used as a visual/tiebreaker for Hidden Gems |

---

## 4. Data quality & exclusions

Applied when building `novacart_campaigns`:

- **Time window** — limited to the last 3 years (`end_date` year ≥ current year − 3), with `end_date >= start_date` enforced (drops records with reversed/invalid date pairs)
- **Invalid activity filter** — rows where `clicks > impressions` or `conversions > clicks` are excluded before aggregation; these indicate internally inconsistent tracking data, not usable for analysis
- **Null exclusion** — 26 campaigns had no matching rows in `fact_campaign_performance` within the 3-year window (`total_impressions`, `total_clicks`, `total_conversion`, `total_cost`, `total_revenue` all null together) and were excluded — documented here rather than silently dropped
- **Segmentation basis** — all medians (`median_roas`, `median_cost`) are calculated per `campaign_type`, not globally, so campaigns are judged against peers with similar channel economics rather than the full dataset


