# Which NovaCart Campaigns Deserve More Budget?

*A SQL + Power BI analysis on a simulated e-commerce marketing dataset*

---

## The question

NovaCart is a simulated e-commerce brand I built to practice a problem every marketing team eventually faces: with a fixed budget spread across hundreds of campaigns, **which ones should get more investment, and which ones aren't earning their spend?**

My first instinct was to ask "which campaigns have the highest ROAS?" But early in the analysis, I found a campaign with an ROAS of roughly 897x — driven by just $2.21 in total spend against about $1,983 in revenue. That single data point reframed the whole project: **ROAS alone can be misleading.** A tiny, barely-tested campaign can produce a spectacular ratio without proving anything repeatable. The real question isn't "what has the highest return" — it's **"what has proven it can generate a strong return, and isn't yet getting the budget to match?"**

That reframe — efficiency *and* scale, considered together — became the backbone of the analysis.


## The data

I generated a synthetic dataset (~220K campaign performance records, ~5,100 campaigns, 3 years of activity) using Claude, deliberately seeding it with the kind of messiness real marketing data actually has: inconsistent date formats, mixed country and device naming, missing revenue values, campaigns with invalid date ranges, and rows that violate the expected funnel logic (conversions can't exceed clicks, clicks can't exceed impressions).


## Cleaning: treating each problem as a decision, not a checklist item

**Missing revenue wasn't one problem — it was two.** Roughly 11,000 rows had a NULL revenue value. Rather than filling every one with zero, I split them:
- ~6,000 rows had zero conversions — no conversion means revenue genuinely should be zero, so these were filled in.
- ~5,000 rows had conversions greater than zero with no recorded revenue — a conversion clearly happened, but its value was never captured. Filling these with zero would have understated real performance, so they were left as NULL: a documented gap, not a fabricated number.

**Invalid data was flagged, not deleted.** Rows where clicks exceeded impressions, where conversions exceeded clicks, and campaigns where the end date came before the start date — each got a boolean flag column instead of being silently removed. That preserves the record and lets any downstream analysis decide whether to include or exclude it, rather than making that call invisibly during cleaning.

**I caught and recovered from my own mistake mid-project.** After renaming and replacing the `record_date` column, I built a backup table from the original source file specifically to verify no data had been lost in the process — a real, if small, example of catching an error before it became a bigger problem.


## Building the segmentation framework

With cleaning done, I calculated core KPIs per campaign — revenue, spend, conversion rate, cost per conversion, and ROAS — then tested how each one ranked campaigns independently. Every single-metric ranking told a different, sometimes contradictory story (the highest-revenue campaign wasn't the most efficient one; the lowest cost-per-conversion campaign wasn't the highest scale). That's what led to building a two-dimensional framework instead:

- **Efficiency** = ROAS (revenue generated per dollar spent)
- **Scale** = total spend (the size of the investment)

Crucially, medians for both were calculated **per campaign type**, not across the whole dataset — a Brand awareness campaign and a Retention campaign have naturally different cost and return profiles, so comparing both against one global number would unfairly penalize or flatter campaigns based on category alone, not actual performance.


## A data integrity bug I caught before it reached the dashboard

While building the final campaign-metrics table in Power BI, I noticed the relationship to the campaign dimension table showed as many-to-one instead of the one-to-one it should have been. Tracing it back, the per-campaign-type median calculation was being joined onto the data *before* it had been properly aggregated to one row per campaign — so any campaign whose type had more than one matching median record got silently duplicated.

I rebuilt the query to aggregate to one row per campaign first, then join descriptive data and medians afterward, joined explicitly on `campaign_type`. I validated the fix at each stage with `COUNT(*) = COUNT(DISTINCT campaign_id)` before trusting any number downstream — the same discipline I'd want in a production reporting pipeline, not just a portfolio exercise.


## Handling outliers honestly

Two metrics needed outlier treatment before the dashboard was readable, and I handled them differently based on *why* each looked the way it did:

- **ROAS**: percentile analysis showed a sharp break between the 75th and 80th percentile (6.4x jumping to 33x) — a sign of the same near-zero-spend distortion I'd found earlier with the 897x campaign, not genuinely exceptional performance. Values above the 75th percentile were excluded from the visualization.
- **Total cost**: this distribution was smoothly right-skewed with no discontinuity — completely normal for marketing spend, where most campaigns run modest budgets and a handful run much larger ones. This wasn't an anomaly to fix, just a readability tradeoff, so a more conservative 95th-percentile cutoff was used instead of treating it the same way as the ROAS issue.


## The result

Across 1,195 campaigns active in the last 3 years:

| Quadrant | Campaigns | Blended ROAS |
|---|---|---|
| High scale & High efficiency | 293 | 3.05x |
| **Low scale & High efficiency** | **323** | **3.26x** |
| High scale & Low efficiency | 299 | 0.90x |
| Low scale & Low efficiency | 280 | 0.82x |

The standout finding: campaigns already receiving heavy investment return **3.05x** — but a group receiving *below-median* spend for their category returns **3.26x**, outperforming the well-funded group entirely. In plain terms: NovaCart's most efficient campaigns aren't the ones getting the most money.


## The recommendation

**Invest in the "Low scale & High efficiency" category.** The data shows these 323 campaigns already produce a higher return than the campaigns currently receiving the most budget. If they can generate 3.26x ROAS at below-median spend, scaling their investment is a direct, low-risk lever for improving overall marketing return — without needing to increase NovaCart's total budget. This is, in short: **scale what's already working.**

## Tools

**PostgreSQL** — CTEs, window functions (`PERCENTILE_CONT`), data validation queries, aggregation-order debugging
**Power BI** — star schema modeling, DAX measures (weighted-ratio calculations via `DIVIDE`, avoiding the unweighted-average trap), quadrant scatter visualization with dynamic reference lines

---

*NovaCart is a simulated company built for portfolio purposes. The dataset is synthetic; the reasoning — investigating misleading metrics, validating aggregation logic, and handling outliers with justification rather than guesswork — reflects the same approach I'd bring to a real dataset.*

