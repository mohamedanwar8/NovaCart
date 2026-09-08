# NovaCart — Which Campaigns Deserve More Budget?

An end-to-end SQL + Power BI analysis answering a real marketing question: given a fixed budget spread across hundreds of campaigns, which ones are proving they can generate strong returns — and deserve more investment — versus which are burning spend without results?

![Dashboard screenshot](powerbi/dashboard-screenshot.png)

## The question

NovaCart (a simulated e-commerce brand) runs marketing campaigns across five types (Acquisition, Awareness, Brand, Conversion, Retention). The goal: identify which campaigns should get more budget going forward, using data instead of gut feel.

## The approach

1. **Cleaned and profiled** a messy, realistic synthetic dataset (~220K records) — inconsistent date formats, mixed country/device naming, missing revenue values, invalid foreign keys, and business-rule violations (e.g. conversions exceeding clicks)
2. **Investigated single-metric ranking and found it misleading** — one campaign showed an ~897x ROAS driven by just $2.21 of total spend, not genuine performance
3. **Built a scale + efficiency framework** instead — comparing each campaign's ROAS and spend against the median for its *own* campaign type (since Brand and Retention campaigns aren't naturally comparable), producing four performance quadrants
4. **Modeled and visualized the result in Power BI** — a quadrant scatter chart, KPI cards, and a supporting table identifying the campaigns worth scaling up

## Key finding

| Quadrant | Campaigns | Blended ROAS |
|---|---|---|
| High scale & High efficiency | 293 | 3.05x |
| **Low scale & High efficiency** | **323** | **3.26x** |
| High scale & Low efficiency | 299 | 0.90x |
| Low scale & Low efficiency | 280 | 0.82x |

The campaigns already receiving the most budget (3.05x ROAS) are actually being **outperformed** by a group receiving below-median spend (3.26x ROAS). This group — proven, efficient, and currently under-invested — represents the clearest opportunity: scale what's already working.

## Repo structure

```
- synthetic-data/   Source CSVs and a README describing the dataset and its intentional data quality issues
- sql/            SQL scripts: data profiling, cleaning, and the final campaign-performance query
- powerbi/         Power BI file (.pbix) and dashboard screenshot
- docs/            Data dictionary for the final analysis table
```

## Tools

- PostgreSQL (CTEs, subquery, window functions, percentile analysis)  
- Power BI (star schema modeling, DAX, Visuals) 
- Claude (synthetic data generation to imitate real world messy data)

---

*NovaCart is a simulated company built for portfolio purposes. The dataset is synthetic; the analytical approach 
data validation, category-fair comparisons, and outlier handling mirrors what I'd apply to a real campaign performance dataset.*
