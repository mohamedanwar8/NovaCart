with campaign_level as (
select 
    dc.campaign_id,
    campaign_name,
    campaign_manager, 
    campaign_type, 
    budget, 
    start_date, 
    end_date,
    start_date - end_date as duration, 
    dc.channel_id,
    target_country,
    fc.device,
    fc.revenue/nullif(fc.spendings,0) as roas,
    fc.impressions,
    fc.clicks,
    fc.conversions,
    fc.spendings,
    fc.revenue,
    fc.record_date,
    fc.country
from dim_campaign as dc
left join fact_campaigns as fc
on fc.campaign_id = dc.campaign_id 
),

last_3_years as (
select * from campaign_level
where extract(year from end_date) >= extract(year from now())-3
order by end_date desc
)



--- join dim campaing with facts and pull all necessary metrics
-- aggregate on campaign level and calaculate the needed metrics
-- count the invalid and null values to exclude and create a clean version of new aggregated campaign level table
-- segment based on campaign type, country, customer ...etc using power bi filters 
-- 


