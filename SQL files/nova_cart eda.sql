--- analyzing each campaign's performance in a nutshell 

select 
    campaign_id,
    total_impressions,
    total_clicks,
    total_conversion,
    total_cost,
    total_revenue,
    round((total_conversion / nullif(total_clicks,0)) *100,2) as conversion_rate,
    round(total_cost/nullif(total_conversion,0) , 2)as cost_per_conversion,
    round(total_revenue/nullif(total_cost,0) ,2) as roas
from (select 
    fact_campaigns.campaign_id,
    sum(revenue) as total_revenue,
    sum(impressions) as total_impressions,
    sum(clicks) as total_clicks,
    sum(conversions) as total_conversion,
    sum(spendings) as total_cost
    
from fact_campaigns

group by     fact_campaigns.campaign_id
)
;


------------------------------

/*
### Task 2

Which campaigns generate the most revenue?
Which generate the most conversions?
Which have the highest ROAS?
Which have the lowest cost per conversion?
Which have the highest conversion rate?
*/


with campaign_summary as (
    select 
    campaign_id,
    total_impressions,
    total_clicks,
    total_conversion,
    total_cost,
    total_revenue,
    total_conversion / nullif(total_clicks,0) *100 as conversion_rate,
    total_cost/nullif(total_conversion,0) as cost_per_conversion,
    total_revenue/nullif(total_cost,0) as roas
from (select 
    fact_campaigns.campaign_id,
    sum(revenue) as total_revenue,
    sum(impressions) as total_impressions,
    sum(clicks) as total_clicks,
    sum(conversions) as total_conversion,
    sum(spendings) as total_cost
    
from fact_campaigns

group by     fact_campaigns.campaign_id
)
)

select campaign_id, roas, total_revenue, total_cost
from campaign_summary
where roas is not null 
order by roas desc
;

-- most revenue = 1512413.71, campaign id is 2896
-- most conversions = 22873, campaign id is 2896
-- highest conversion rate is 97.56, campaign id is 8668
-- lowest per conversion; multiple campaigns at 0.0025 cost per conversion, the lowest campaign id is 9062
-- Highest ROAS = 897.35, campaign id is 734




--------  --------------------------------

-- Scale & Efficiency 
-- efficiency metric = ROAS
-- Scale metric = cost
-- column for scale, one for efficiency = low or high comparing to the median



with campaign_performance as (
    select 
    campaign_id,
    total_cost,
    total_revenue/nullif(total_cost,0) as roas
    from (
        select 
        fact_campaigns.campaign_id,
        sum(revenue) as total_revenue,
        sum(spendings) as total_cost
        from fact_campaigns
        group by     fact_campaigns.campaign_id
) as campaign_totals
),

medians as (
    select 
        percentile_cont(.5) within group(order by total_cost) as median_cost,
        percentile_cont(.5) within group(order by roas) as median_roas
    from campaign_performance
    ) 
    
select
    campaign_id,
    total_cost,
    roas,
    scale,
    efficiency,
    concat(scale, ' scale + ', efficiency, ' efficiency')
from (
        select 
            campaign_id,
            total_cost,
            roas,
            case 
                when total_cost >= m.median_cost then 'High'
                else 'Low'
                End as scale,
            case 
                when roas >= m.median_roas then 'High'
                else 'Low'
                End as efficiency
            
        from campaign_performance as pc
        cross join medians as m
        );


------------------------------------------
--- counting scale and efficiency segments


with campaign_performance as (
    select 
    campaign_id,
    total_cost,
    total_revenue/nullif(total_cost,0) as roas
    from (
        select 
        fact_campaigns.campaign_id,
        sum(revenue) as total_revenue,
        sum(spendings) as total_cost
        from fact_campaigns
        group by     fact_campaigns.campaign_id
) as campaign_totals
),

medians as (
    select 
        percentile_cont(.5) within group(order by total_cost) as median_cost,
        percentile_cont(.5) within group(order by roas) as median_roas
    from campaign_performance
    ) 
, 
segments as (
    select
        campaign_id,
        total_cost,
        roas,
        scale,
        efficiency,
        concat(scale, ' scale + ', efficiency, ' efficiency') as scale_efficiency
    from (
            select 
                campaign_id,
                total_cost,
                roas,
                case 
                    when total_cost >= m.median_cost then 'High'
                    else 'Low'
                    End as scale,
                case 
                    when roas >= m.median_roas then 'High'
                    else 'Low'
                    End as efficiency
                
            from campaign_performance as pc
            cross join medians as m
            )
)

select 
    count(*)
FROM segments 
where scale_efficiency = 'Low scale +  efficiency';


--- count of high scale + high efficiency = 1962

--- count of high scale + low efficiency = 1748

--- count of Low scale + high efficiency = 1711

--- count of low scale + low efficiency = 1998



----------------------------

-- Analyzing hihg scale + high efficiency campaigns


with campaign_totals as (
        select 
        fact_campaigns.campaign_id,
        sum(revenue) as total_revenue,
        sum(spendings) as total_cost,
        sum(conversions) as total_conversion,
        sum(revenue)/nullif(sum(spendings),0) as roas,
        (sum(conversions)/nullif(sum(clicks) ,0)) * 100 as conversion_rate,
        sum(spendings)/nullif(sum(conversions) ,0) as cost_per_conversion   
        from fact_campaigns
        group by fact_campaigns.campaign_id
)
,
medians as (
    select 
        percentile_cont(0.5) within group (order by total_cost) as median_cost,
        percentile_cont(.5) within group (order by roas) as median_roas
    from campaign_totals
)
,
scale_efficiency as (
    select *,
        case 
            when total_cost >= m.median_cost and roas >= m.median_roas then 'High scale + High efficiency'
            else 'Excluded'
            end sub_segments
        from campaign_totals
        cross join medians as m  
)
select * from scale_efficiency
where sub_segments = 'High scale + High efficiency'
order by cost_per_conversion;



------------------------------------------------------

-- Trend and time analysis

-- initial analysis (range, min, max, count distinct dates, granularity)
select count(record_date)
from fact_campaigns
limit 5;



-- campaign X year

with campaign_totals as (
        select 
        fact_campaigns.campaign_id,
        sum(revenue) as total_revenue,
        sum(spendings) as total_cost,
        sum(revenue)/nullif(sum(spendings),0) as roas
        from fact_campaigns
        group by fact_campaigns.campaign_id
)
,
medians as (
    select 
        percentile_cont(0.5) within group (order by total_cost) as median_cost,
        percentile_cont(.5) within group (order by roas) as median_roas
    from campaign_totals
)
,
high_performers as (
    select *
        from campaign_totals as ct
        cross join medians as m  
        where total_cost >= m.median_cost and roas >= m.median_roas
)
,
performance_year as (
    select 
        hp.campaign_id,
        extract(year from fc.record_date) as year,
        sum(fc.revenue) as total_revenue,
        sum(fc.spendings) as total_cost,
        sum(fc.conversions) as total_conversion,
        sum(fc.revenue)/nullif(sum(fc.spendings),0) as roas,
        (sum(fc.conversions)/nullif(sum(fc.clicks) ,0)) * 100 as conversion_rate,
        sum(fc.spendings)/nullif(sum(fc.conversions) ,0) as cost_per_conversion 
    from high_performers as hp
    inner join fact_campaigns as fc
    on fc.campaign_id = hp.campaign_id
    group by hp.campaign_id, year
)

select * from performance_year;



----------------------
-- high performers start, end, and duration + duration stats


with campaign_totals as (
        select 
        fact_campaigns.campaign_id,
        sum(revenue) as total_revenue,
        sum(spendings) as total_cost,
        sum(revenue)/nullif(sum(spendings),0) as roas
        from fact_campaigns
        group by fact_campaigns.campaign_id
)
,
medians as (
    select 
        percentile_cont(0.5) within group (order by total_cost) as median_cost,
        percentile_cont(.5) within group (order by roas) as median_roas
    from campaign_totals
)
,
high_performers as (
    select *
        from campaign_totals as ct
        cross join medians as m  
        where total_cost >= m.median_cost and roas >= m.median_roas
)
,

campaign_duration as (
    select 
        hp.campaign_id,
        min(fc.record_date) as first_date,
        max(fc.record_date) as last_date,
        max(fc.record_date)  - min(fc.record_date)  as duration
        
    from high_performers as hp
    inner join fact_campaigns as fc
    on fc.campaign_id = hp.campaign_id
    group by hp.campaign_id
)
,

duration_stats as (
    select 
        min(duration) as min_duration,
        percentile_cont(0.25) within group (order by duration) as q1_duration,
        percentile_cont(0.5)  within group (order by duration) as median_duration,
        percentile_cont(0.75) within group (order by duration) as q3_duration,
        avg(duration) as avg_duration,
        max(duration) as max_duration
        
    from campaign_duration
)

select * from duration_stats;


/*
,
durations_distribution as (
    select 
        cd.campaign_id,
        cd.first_date,
        cd.last_date,
        cd.duration,
        avg_duration,
        case 
            when cd.duration = ds.median_duration then 'Median'
            when cd.duration >= ds.q3_duration then 'Q3'
            when cd.duration <= ds.q1_duration then 'Q1'
            else 'regular'
        end as distribution
    from campaign_duration as cd
    cross join duration_stats as ds
)

select * from durations_distribution

*/



---------------------------
--- Annual performance 


with campaign_totals as (
        select 
        fact_campaigns.campaign_id,
        sum(revenue) as total_revenue,
        sum(spendings) as total_cost,
        sum(revenue)/nullif(sum(spendings),0) as roas
        from fact_campaigns
        group by fact_campaigns.campaign_id
)
,
medians as (
    select 
        percentile_cont(0.5) within group (order by total_cost) as median_cost,
        percentile_cont(.5) within group (order by roas) as median_roas
    from campaign_totals
)
,
high_performers as (
    select *
        from campaign_totals as ct
        cross join medians as m  
        where total_cost >= m.median_cost and roas >= m.median_roas
)
,
performance_year as (
    select 
        hp.campaign_id,
        extract(year from fc.record_date) as year,
        sum(fc.revenue) as total_revenue,
        sum(fc.spendings) as total_cost,
        sum(fc.conversions) as total_conversion,
        sum(fc.revenue)/nullif(sum(fc.spendings),0) as roas,
        (sum(fc.conversions)/nullif(sum(fc.clicks) ,0)) * 100 as conversion_rate,
        sum(fc.spendings)/nullif(sum(fc.conversions) ,0) as cost_per_conversion 
    from high_performers as hp
    inner join fact_campaigns as fc
    on fc.campaign_id = hp.campaign_id
    group by hp.campaign_id, year
)

select * from performance_year
;



-------------------------
-- Individual campaign YOY trends 



with campaign_totals as (
        select 
        fact_campaigns.campaign_id,
        sum(revenue) as total_revenue,
        sum(spendings) as total_cost,
        sum(revenue)/nullif(sum(spendings),0) as roas
        from fact_campaigns
        group by fact_campaigns.campaign_id
)
,
medians as (
    select 
        percentile_cont(0.5) within group (order by total_cost) as median_cost,
        percentile_cont(.5) within group (order by roas) as median_roas
    from campaign_totals
)
,
high_performers as (
    select *
        from campaign_totals as ct
        cross join medians as m  
        where total_cost >= m.median_cost and roas >= m.median_roas
)

,
calendar_years as (
    select 
        hp.campaign_id,
        generate_series(
            min(extract(year from fc.record_date)),
            max(extract(year from fc.record_date)),
            1
        ) as calendar_year
    from high_performers as hp
    inner join fact_campaigns as fc
        on fc.campaign_id = hp.campaign_id
    group by hp.campaign_id
)

,

actual_performance_year as (
    select 
        hp.campaign_id,
        extract(year from fc.record_date) as year,
        sum(fc.revenue) as total_revenue,
        sum(fc.spendings) as total_cost,
        sum(fc.conversions) as total_conversion,
        sum(fc.revenue)/nullif(sum(fc.spendings),0) as roas,
        (sum(fc.conversions)/nullif(sum(fc.clicks) ,0)) * 100 as conversion_rate,
        sum(fc.spendings)/nullif(sum(fc.conversions) ,0) as cost_per_conversion 
    from high_performers as hp
    inner join fact_campaigns as fc
    on fc.campaign_id = hp.campaign_id
    group by hp.campaign_id, year
    
),
yearly_performance as (
    select 
        cy.campaign_id,
        cy.calendar_year,
        ap.total_revenue,
        ap.total_cost,
        ap.total_conversion,
        ap.roas,
        ap.conversion_rate,
        ap.cost_per_conversion
    from calendar_years as cy
    left join actual_performance_year as ap
        on cy.campaign_id = ap.campaign_id 
        and cy.calendar_year = ap.year

)

select 
    campaign_id,
    calendar_year,
    total_revenue,
    lag(total_revenue,1) over(partition by campaign_id order by calendar_year) as prev_year_revenue,
    (total_revenue - lag(total_revenue,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(total_revenue,1) over(partition by campaign_id order by calendar_year),0) * 100
    as revenue_change,

    total_cost,
    lag(total_cost,1) over(partition by campaign_id order by calendar_year) as prev_year_cost,
    (total_cost - lag(total_cost,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(total_cost,1) over(partition by campaign_id order by calendar_year),0) * 100
    as cost_change,

    total_conversion,
    lag(total_conversion,1) over(partition by campaign_id order by calendar_year) as prev_year_conversion,
    (total_conversion - lag(total_conversion,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(total_conversion,1) over(partition by campaign_id order by calendar_year),0) * 100
    as conversion_change,
    roas,
    lag(roas,1) over(partition by campaign_id order by calendar_year) as prev_year_roas,
    (roas - lag(roas,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(roas,1) over(partition by campaign_id order by calendar_year),0) * 100
    as roas_change,

    cost_per_conversion,
    lag(cost_per_conversion,1) over(partition by campaign_id order by calendar_year) as prev_year_cpr,
    (cost_per_conversion - lag(cost_per_conversion,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(cost_per_conversion,1) over(partition by campaign_id order by calendar_year),0) * 100
    as cpr_change,

    conversion_rate,
    lag(conversion_rate,1) over(partition by campaign_id order by calendar_year) as prev_year_conv_rate,
    (conversion_rate - lag(conversion_rate,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(conversion_rate,1) over(partition by campaign_id order by calendar_year),0) * 100
    as conversion_rate_change

from yearly_performance
;





-----------------------------------------------------
-- campaign lifecycle analysis


with campaign_totals as (
        select 
        fact_campaigns.campaign_id,
        sum(revenue) as total_revenue,
        sum(spendings) as total_cost,
        sum(revenue)/nullif(sum(spendings),0) as roas
        from fact_campaigns
        group by fact_campaigns.campaign_id
)
,
medians as (
    select 
        percentile_cont(0.5) within group (order by total_cost) as median_cost,
        percentile_cont(.5) within group (order by roas) as median_roas
    from campaign_totals
)
,
high_performers as (
    select *
        from campaign_totals as ct
        cross join medians as m  
        where total_cost >= m.median_cost and roas >= m.median_roas
)

,
calendar_years as (
    select 
        hp.campaign_id,
        generate_series(
            min(extract(year from fc.record_date)),
            max(extract(year from fc.record_date)),
            1
        ) as calendar_year
    from high_performers as hp
    inner join fact_campaigns as fc
        on fc.campaign_id = hp.campaign_id
    group by hp.campaign_id
)

,

actual_performance_year as (
    select 
        hp.campaign_id,
        extract(year from fc.record_date) as year,
        sum(fc.revenue) as total_revenue,
        sum(fc.spendings) as total_cost,
        sum(fc.conversions) as total_conversion,
        sum(fc.revenue)/nullif(sum(fc.spendings),0) as roas,
        (sum(fc.conversions)/nullif(sum(fc.clicks) ,0)) * 100 as conversion_rate,
        sum(fc.spendings)/nullif(sum(fc.conversions) ,0) as cost_per_conversion 
    from high_performers as hp
    inner join fact_campaigns as fc
    on fc.campaign_id = hp.campaign_id
    group by hp.campaign_id, year
    
),
yearly_performance as (
    select 
        cy.campaign_id,
        cy.calendar_year,
        ap.year,
        ap.total_revenue,
        ap.total_cost,
        ap.total_conversion,
        ap.roas,
        ap.conversion_rate,
        ap.cost_per_conversion
    from calendar_years as cy
    left join actual_performance_year as ap
        on cy.campaign_id = ap.campaign_id 
        and cy.calendar_year = ap.year
)

,
yearly_gaps as (
    select 
    campaign_id,
    calendar_year,
    year
from yearly_performance as yp
where year is not null
)
,
multi_year_campaigns as (
select 
    campaign_id,
    count(year)
from yearly_performance
group by campaign_id
having count(year) > 1
)


select 
    *,
    ct.total_revenue,
    ct.total_cost,
    ct.roas,
    ct.total_revenue - ct.total_cost as profit

from multi_year_campaigns as my
left join campaign_totals as ct
on my.campaign_id = ct.campaign_id


-- there is 1707 campaign lasted less than a year and 254 more than a year
-- i will focus on the 254 as the have longer history 







/*
,
yoy as (
    
select 
    campaign_id,
    calendar_year,
    total_revenue,
    lag(total_revenue,1) over(partition by campaign_id order by calendar_year) as prev_year_revenue,
    (total_revenue - lag(total_revenue,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(total_revenue,1) over(partition by campaign_id order by calendar_year),0) * 100
    as revenue_change,

    total_cost,
    lag(total_cost,1) over(partition by campaign_id order by calendar_year) as prev_year_cost,
    (total_cost - lag(total_cost,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(total_cost,1) over(partition by campaign_id order by calendar_year),0) * 100
    as cost_change,

    total_conversion,
    lag(total_conversion,1) over(partition by campaign_id order by calendar_year) as prev_year_conversion,
    (total_conversion - lag(total_conversion,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(total_conversion,1) over(partition by campaign_id order by calendar_year),0) * 100
    as conversion_change,
    roas,
    lag(roas,1) over(partition by campaign_id order by calendar_year) as prev_year_roas,
    (roas - lag(roas,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(roas,1) over(partition by campaign_id order by calendar_year),0) * 100
    as roas_change,

    cost_per_conversion,
    lag(cost_per_conversion,1) over(partition by campaign_id order by calendar_year) as prev_year_cpr,
    (cost_per_conversion - lag(cost_per_conversion,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(cost_per_conversion,1) over(partition by campaign_id order by calendar_year),0) * 100
    as cpr_change,

    conversion_rate,
    lag(conversion_rate,1) over(partition by campaign_id order by calendar_year) as prev_year_conv_rate,
    (conversion_rate - lag(conversion_rate,1) over(partition by campaign_id order by calendar_year)) 
    / 
    nullif(lag(conversion_rate,1) over(partition by campaign_id order by calendar_year),0) * 100
    as conversion_rate_change

from yearly_performance

)
*/