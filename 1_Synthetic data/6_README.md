# NovaCart Marketing Campaign Performance — Synthetic Dataset

Generated to match the NovaCart project brief: a messy, realistic marketing
dataset for a fictional global e-commerce company, structured as a star schema.

Random seed: 42 (fully reproducible from `generate_novacart.py` + `generate_fact.py`).

## Files

| File | Rows | Description |
|---|---:|---|
| `dim_channel.csv` | 15 | Marketing channel lookup |
| `dim_date.csv` | 2,192 | Calendar dimension, 2019-01-01 to 2024-12-31 |
| `dim_customer.csv` | 5,150 | Customer demographics & segmentation |
| `dim_campaign.csv` | 5,100 | Campaign metadata |
| `fact_campaign_performance.csv` | 220,375 | Grain: one row per campaign/customer touchpoint |

Row counts run slightly above the brief's targets because duplicate records
were appended on top of the base counts (5,000 / 5,000 / 200,000+), which is
itself one of the intentional data quality issues — see below.

## Schema (star schema)

```
dim_campaign ---\
dim_customer ----+--> fact_campaign_performance
dim_channel  ---/
dim_date     (join fact.record_date, once parsed/cleaned, to dim_date.full_date)
```

Note: `fact_campaign_performance.record_date` is intentionally left as a raw,
inconsistently formatted string (see below) rather than a clean foreign key to
`dim_date`. Part of the exercise is parsing/standardizing it and joining it in.

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

## Intentional data quality issues (all from the brief, all present and measurable)

| Issue | Where | Approx. rate |
|---|---|---:|
| Missing campaign manager | dim_campaign | 15% |
| Missing/blank campaign name | dim_campaign | 3% |
| Missing/blank email | dim_customer | 5% |
| Missing revenue | fact | 5% |
| Missing customer_id | fact | 2% |
| Duplicate campaigns | dim_campaign | 2% appended |
| Duplicate customers | dim_customer | 3% appended |
| Duplicate performance records | fact | 2.5% appended |
| Mixed capitalization / whitespace | names, campaign names, device, country | throughout |
| Inconsistent country names (USA/US/United States/etc.) | dim_customer, fact | throughout |
| Inconsistent device naming (mobile/Mobile/MOBILE/Smartphone) | fact | 20% |
| Multiple date formats (ISO, US, EU, "13 Oct 2023", etc.) | fact.record_date | throughout |
| Blank/invalid date strings ("N/A", "00/00/0000") | fact.record_date | ~0.8% |
| Invalid foreign keys (campaign_id/customer_id not in dims) | fact | 1.5% each |
| Clicks > impressions | fact | ~1.2% |
| Conversions > clicks | fact | ~1.0% |
| Negative revenue | fact | ~0.6% |
| Zero spend with conversions > 0 | fact | ~1.0% |
| Outliers (extreme spend/impression spikes, 10–60x) | fact | ~0.4% |
| Invalid campaign dates (end before start) | dim_campaign | 2% |

## Built-in realism (so the analysis has a real story to tell)

- Spend is allocated across campaigns on a lognormal/power-law curve — a
  minority of campaigns absorb most of the budget.
- Each channel has its own CTR/CVR/CPC/AOV benchmark (e.g. Email and Organic
  Search convert well and cost little; LinkedIn has high CPC and mid CVR;
  Display has weak CTR/CVR), so channel comparisons produce a real ROI ranking.
- Seasonality: November/December volume is boosted ~1.6x (Black Friday /
  holiday), January/February dips ~0.7x.
- Device affects conversion likelihood (desktop slightly outperforms mobile/tablet).
- Revenue = conversions × channel AOV × lognormal noise, so there's a
  believable spread of order values including occasional high-value orders.

## KPIs you can derive

Revenue, Spend, Profit (Revenue − Spend), ROI (Profit / Spend), ROAS (Revenue / Spend),
CTR (Clicks / Impressions), CPC (Spend / Clicks), CPM (Spend / Impressions × 1000),
CPA (Spend / Conversions), Conversion Rate (Conversions / Clicks).

## Suggested cleaning steps 

1. Standardize `country` values to a canonical list (map aliases → full names).
2. Standardize `device` values (trim, title-case, map "Smartphone"→"Mobile", "PC"→"Desktop").
3. Parse `record_date` across its multiple formats into a real date, drop/flag unparseable rows, join to `dim_date`.
4. Deduplicate `fact_campaign_performance`, `dim_campaign`, `dim_customer` (decide keep-first vs keep-last policy).
5. Flag/exclude or correct rows where clicks > impressions or conversions > clicks.
6. Decide a policy for negative revenue (treat as refunds vs. exclude).
7. Handle missing revenue (exclude from revenue KPIs vs. impute).
8. Handle invalid foreign keys (orphan fact rows with no matching dim row).
