
-- fact campaigns cleaning

select distinct record_date  
from fact_campaigns;


/*
- change the record_date format to make it consistent as a date
- deal with missing values in the impressions, clicks, conversions, spendings, and revenue columns
- data normalization for the device column to transform the data into a standard and consistent form
- data standarization for the country column


investigating missing values

- no null values in clicks, impressions, spendings, or conversions columns
- 10949 null values in revenue, 209426 not null values
- there is no duplicate values 

*/



--- checking different date patterns in record_date
SELECT DISTINCT 
    REGEXP_REPLACE(record_date, '[0-9]', 'X', 'g') AS date_pattern
FROM fact_campaigns;



-- standardizing the record date column  

-- adding a new column to clean the date
ALTER TABLE fact_campaigns
ADD COLUMN record_date_clean date;

-- cleaning the date 

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

    ELSE NULL  -- catches '', '----', and anything unexpected
END;



-- validating the new record date column 
SELECT record_date, count(*) 
FROM fact_campaigns
WHERE record_date_clean IS NULL 
  AND record_date NOT IN ('', '----')
GROUP BY record_date;



-- replacing record_date with record_date clean
alter table fact_campaigns drop COLUMN record_date;
alter table fact_campaigns rename column record_date_clean to record_date;

-- validation
select record_date from fact_campaigns;



--- device column: normalizing values 

update fact_campaigns
set device = trim( initcap(device))

-- validation
select 
    DISTINCT device 
from fact_campaigns;



-- cleaning the country and normalizing it

select distinct trim(initcap(replace(country, '.',''))) as 
from fact_campaigns;

alter table fact_campaigns
add column country_clean VARCHAR(255);


-- creating a column for cleaned, normalized data

update fact_campaigns
set country_clean = trim(initcap(replace(country, '.','')));


update fact_campaigns
set country_clean = case 
        when country_clean = 'Uk' then 'United Kingdom'
        When country_clean = 'Us' then 'United States'
        When country_clean = 'Usa' then 'United States'
        When country_clean = 'Uae' then 'United Arab Emirates'
        else country_clean 
    end ;



-- Validation
select distinct country_clean
from fact_campaigns

-- updating and replacing the original country with the cleaned one 
alter table fact_campaigns drop column country;
alter table fact_campaigns rename column country_clean to country; 




-- cleaning the country column in the customer table
select distinct trim(initcap(replace(country, '.', ''))) from dim_customer;

alter table dim_customer
add column country_clean VARCHAR(255)

update dim_customer
set country_clean = trim(initcap(replace(country, '.', ''))) 
 
 -- validating cleaning result
select distinct country_clean, 
case
    when country_clean = 'Us' or country_clean = 'Usa' then 'United States'
    when country_clean = 'Uae' then 'United Arab Emirates'
    when country_clean = 'Uk' then 'United Kingdom'
    else country_clean
End
from dim_customer

alter table dim_customer drop column country;
alter table dim_customer rename column country_clean to country;

update dim_customer
set 
country = case
                when country= 'Us' or country = 'Usa' then 'United States'
                when country= 'Uae' then 'United Arab Emirates'
                when country = 'Uk' then 'United Kingdom'
                else country
            End;



-- validation
select distinct country from dim_customer;

-- ensuring country in fact campaigns has the same values as country in customer 
SELECT DISTINCT country
FROM fact_campaigns
EXCEPT
SELECT DISTINCT country
FROM dim_customer;




-- checking city column (doesn't need cleaning)
select  distinct city from dim_customer;



-- revenue column

select revenue from fact_campaigns
where revenue is null and conversions>0;


--- replacing 6001 null values with 0 as the conversion = 0
-- keeping the 4948 revenue null value as them because conversion is more than 0 and this doesn't make sense (missing values).


-- updating null values in revenue column with 0 conversion
update fact_campaigns
set revenue = 0 
where revenue is null and conversions = 0;


-- business rule violations

select * from fact_campaign
where clicks > impressions;

-- create a column to flag invalid data to document the error (clicks > impressions)

alter table fact_campaigns
add column invalid_clicks boolean;

update fact_campaigns
set invalid_clicks = 
        case 
            when clicks > impressions then true
            else false
            end 

select count(invalid_clicks) from fact_campaigns
where invalid_clicks is true;



-- create a column to flag invalid data to document the error (conversions > clicks)

alter table fact_campaigns
add column invalid_conversion boolean;

update fact_campaigns
set invalid_conversion = 
        case 
            when conversions > clicks then true
            else false
            end 

select count(invalid_conversion) from fact_campaigns
where invalid_conversion is true;



---- validating logic end and start date 

select * from dim_campaign
where start_date > end_date;

-- quantifying the influence of the invalid dates 
select 
    count(*),
    count(*)*100 / (select count(*) from dim_campaign)
    from dim_campaign
    where end_date <start_date 


-- there are 103 invalid values and it affects 2% of the data in the dim_campaign


--- adding an invalid date column to flag invalid start and end dates

alter table dim_campaign
add column invalid_date date;

-- i made a mistake by creating invalid_date as date it should've been boolean

alter table  dim_campaign
alter column invalid_date type boolean using(invalid_date is not null); 

update dim_campaign
set invalid_date =
    case when start_date > end_date then true
        else false 
        end;

-- new column validation 
select 
    start_date,
    end_date, 
    invalid_date 
from dim_campaign
where start_date > end_date



---------------------------------------------------
-- from profiling stage: 3321 campaign ids don't exist in in dim campaign

select count(*) invalid_fact_id,
    round(count(*) * 100.0 / (select count(*) from fact_campaigns),2) as percentage
from fact_campaigns as f
left join dim_campaign as p
on p.campaign_id = f.campaign_id 
where p.campaign_id is null;


-- counting unique missing values
select count (distinct campaign_id)
from fact_campaigns
where campaign_id not in (select campaign_id from dim_campaign);


-- cost and revenue of these missing campaigns

select 
    campaign_id,
    count (*) as missing,
    sum(revenue) as total_rev, sum(spendings) as total_cost

from fact_campaigns
where campaign_id not in (select campaign_id from dim_campaign)
group by campaign_id
order by total_cost desc;



-- creating a flag column to flag missing id from dim campaign

alter table fact_campaigns
add column id_flag boolean;

UPDATE fact_campaigns as f
SET id_flag = TRUE
WHERE NOT EXISTS (
    SELECT campaign_id
    FROM dim_campaign as c
    WHERE c.campaign_id = f.campaign_id
);

UPDATE fact_campaigns
SET id_flag = FALSE
WHERE id_flag IS NULL;


/*
-- total number of missing ids is 3321
-- affected percentage is 1.51 so i will leave it there and just document it  
-- 2379 unique misisng values in campaign_id (in fact table but not in the dimensional)
-- maximum total revenue is 19324.08, maximum total cost is  6860.31
-- id_flag column has a true value for each id does exist in fact table but not in the dim table

*/




-- importing the original data of record_dates to fix the missing values as i made a mistake and deleted the original column

create table fact_campaigns_backup(
    fact_id int,
    camaign_id int, 
    customer_id int,
    channel_id int,
    record_date text,
    device varchar(50),
    country varchar(50),
    impressions NUMERIC,
    clicks NUMERIC,
    conversions NUMERIC,
    spendings DECIMAL,
    revenue decimal

);

alter table fact_campaigns_backup
rename column camaign_id to campaign_id;

copy fact_campaigns_backup FROM 'G:/Portfolio/marketing campaign project/fact_campaign_performance.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');


select  distinct f.fact_id ,  f.record_date, b.record_date from fact_campaigns as f
left JOIN fact_campaigns_backup as b
on b.fact_id = f.fact_id
where f.record_date is not null and b.record_date is  null;


--- the data in record date in fact table is correct 



