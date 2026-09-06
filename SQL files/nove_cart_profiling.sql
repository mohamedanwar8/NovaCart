/*
1. create a database called nova_cart
2. create 5 tables with the necessary columns to import the csv files 
in order (fact_campaign, dim_campaign, dim_channel, dim_customer, dim_date)
*/


create database nova_cart; 

create table fact_campaigns(
    fact_id int,
    camaign_id int, 
    customer_id int,
    channel_id int,
    record_date date,
    device varchar(50),
    country varchar(50),
    impressions NUMERIC,
    clicks NUMERIC,
    conversions NUMERIC,
    spendings DECIMAL,
    revenue decimal

);

-- changing the datatype of the record_date column
alter table fact_campaigns 
alter column record_date type VARCHAR(50)



create table dim_campaign(
    campaign_id int,
    campaign_name VARCHAR(250),
    channel_id int,
    campaign_manager varchar(50),
    start_date date,
    end_date date,
    budget DECIMAL,
    campaign_type VARCHAR(50),
    target_segment VARCHAR(50),
    target_country VARCHAR(50)
);


create table dim_channel(
    channel_id int,
    channel_name VARCHAR(50),
    channel_subtype VARCHAR(50),
    channel_category VARCHAR(50)
);




-- i forgot a column so i will delete the table then adjust the creation code 
drop table dim_customer

-- creating the table again
create table dim_customer(
    customer_id int,
    first_name VARCHAR(50),
    last_name varchar(50),
    email text,
    age int,
    gender VARCHAR(25),
    country VARCHAR(50),
    city text,
    segment VARCHAR(50),
    signup_date date,
    preferred_device VARCHAR(50)

);


create table dim_date(
    date_id int,
    full_date date,
    day int,
    month int,
    month_name VARCHAR (25),
    quarter int,
    year int,
    day_of_week VARCHAR (50),
    is_weekend boolean
);





-- droping all the data in the tables to eliminate duplicates
truncate table fact_campaigns, dim_campaign, dim_customer, dim_date, dim_channel

/*
Import the csv files in the tables i created
*/

copy fact_campaigns FROM 'G:/Portfolio/marketing campaign project/fact_campaign_performance.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');

copy dim_campaign from 'G:/Portfolio/marketing campaign project/dim_campaign.csv' with (format csv,  header true, delimiter ',');

copy dim_customer from 'G:/Portfolio/marketing campaign project/dim_customer.csv' with (format csv, header true, delimiter ',');

copy dim_date from 'G:/Portfolio/marketing campaign project/dim_date.csv' with (format csv, header true, delimiter ',');

copy dim_channel from 'G:/Portfolio/marketing campaign project/dim_channel.csv' with (format csv, header true, delimiter ',');




/* ensuring that i have the data 
*/

select count(*) from fact_campaigns;
select count(*) from dim_campaign;
select count(*) from dim_channel;
select count(*) from dim_customer;
select count(*) from dim_date;



--------------------
/*
Exploring the data
table by table 
*/






-- fact_campaigns data profiling


select  * from fact_campaigns
limit 10

select distinct device  from fact_campaigns;

select distinct country  from fact_campaigns;


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

select count(*) from fact_campaigns
where revenue is null;


-- checking duplicate values
select count(*) from fact_campaigns;
select count(distinct fact_campaigns) from fact_campaigns;

-- or 

select count(fact_id) from fact_campaigns;
select count(distinct fact_id) from fact_campaigns;


-- device column exploration

select distinct device from fact_campaigns;

/* 
The device column contains 16 distinct values, although they represent only 3 logical categories. 
This indicates inconsistent capitalization and formatting that will require standardization.
*/


-- country column exploration

select distinct country from fact_campaigns;

-- there are multiple rows has the same values but in different formats (need standarization). 


-- profiling the numeric values: impressions, clicks, conversions, spendings, revenue 
select 
    min(impressions) as min_impressions,
    min(clicks) as min_clicks,
    min(conversions) as min_conversions,
    min(spendings) as min_spendings,
    min(revenue) as min_revenue
from fact_campaigns;

/*
minimum value for each of 
impressions= 20
clicks, conversion, spendings = 0
revenue = -12969.81

*/

select 
    max(impressions) as max_impressions,
    max(clicks) as max_clicks,
    max(conversions) as max_conversions,
    max(spendings) as max_spendings,
    max(revenue) as max_revenue
from fact_campaigns;

/*
maximum values:
impressions = 2127506
clicks = 86687
conversions = 18954
spendings = 50209.42989
revenue = 395347.07

The revenue column contains negative values. 
These require business validation because they may represent refunds, returns, accounting adjustments, or data quality issues.
*/

-- marketing check; is there any impressions record < clicks or clicks < conversion
select count(*) from fact_campaigns
where impressions < clicks;

select count(*) from fact_campaigns
where clicks < conversions;

/*
less impressions than clicks = 2637
less clicks than conversions = 2233 
*/


/*
the main challenges with the fact_campaigns table are 
Missing revenue
Inconsistent devices
Inconsistent countries
Negative revenue
Business rule violations

*/

-- i made a mistake naming the campaign_id column in the fact_campaigns table so i needed to rename it
alter table fact_campaigns
rename column camaign_id to campaign_id 


-- checking the integrity of the campaign id in the fact table
select * from fact_campaigns as f 
left join dim_campaign as c 
on f.campaign_id = c.campaign_id
where c.campaign_id is null;


-- There are 3,321 rows in the fact table whose campaign_id has no matching record in dim_campaign.


-- date range

-- selecting the date types; identify the different data types in the column to be able to profile it
select column_name, data_type
from information_schema.columns
where table_name = 'fact_campaigns' and column_name = 'record_date';

/* The record_date column is stored as a text (VARCHAR) field instead of a date type. 
In addition, the column contains multiple date formats, 
preventing reliable chronological analysis until the data is standardized and converted to a proper DATE data type.
*/




---------------------
-------------------
-- profiling dimensions 

select * from dim_campaign limit 5;



/*
campaign dimension profiling
- each row represents a campaign
- each campaign has a campaign name, channel id, manager, 
start & end date, budget, type, target segment, and country
- the primary key is campaign_id
- campaign id doesn't have duplicates or null values 
*/

select count(campaign_id) from dim_campaign
where campaign_id is null;


-- checking null values in all columns 
select count(*) from dim_campaign
where campaign_name is null;

select count(*) from dim_campaign
where campaign_manager is null
;

select count(*) from dim_campaign
where end_date is null
;


select count(*) from dim_campaign
where budget is null
;


select count(*) from dim_campaign
where campaign_type is null
;


select count(*) from dim_campaign
where target_segment is null
;


select count(*) from dim_campaign
where target_country is null
;



/*
- campaign_id has 151 null values 
- campaign manager has 769 null values
- 0 nulls in  channel_id, start date, end date, budget, campaign_type, target_segment, and target country

*/


-- investigating dimensional columns
-- dim campaign

select distinct campaign_type from dim_campaign;

/*
campaign type, target_country, target_segment have unique values 
*/


-- business logic check; is there any campaign ends before start?
select count(*) from dim_campaign 
where end_date < start_date

/*
103 campaigns violate the business rule that a campaign must start on or before its end date. 
These records require correction before calculating campaign duration or performing time-based analysis.
*/


-- Determine whether campaign budgets are reasonable.

select 
    min(budget),
    max(budget)
    from dim_campaign

-- no negative values, no zero budgets



-- dim customer profiling

select * from dim_customer limit 3;

/*
- One row represents: One customer.
- Primary key: customer_id
- ID column: customer_id
- Descriptive attributes: first_name, last_name, email, gender, country, city, segment, signup_date, preferred_device
- Numeric attribute: age

- columns need standaraization: country, city
- segment has 102 null values 
- country has 156 nulls 
- mail has 256 nulls
- the rest of the columns have no nulls


*/



-- checking for duplicates in the customer id
SELECT
    customer_id,
    COUNT(*)
FROM dim_customer
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- checking nulls 
select count(*) from dim_customer
where email is null;


-- data consistency
select distinct gender from dim_customer;


-- validity checks 
select min(age), max(age)
from dim_customer

-- minimum age is 18, maximum age is 75; no negative values, 0 values, or unrealistic ages



-- validating email column
select * from dim_customer 
where email not like '%@%';


--no trailing or leading spaces 
select * from dim_customer 
where email <> trim(email);


-- emails with more than one @
SELECT *
FROM dim_customer
WHERE LENGTH(email) - LENGTH(REPLACE(email, '@', '')) > 1 or email ='';




/* 
dim channel profiling
one row means a channel, its name, subtype, and category
- primary key: channel id
- dimensions: channel_name, subtype, and category
- all of the dimensions have standardized data 
- no duplicates in the channel_id
- no null values


*/

select * from dim_channel
limit 3;


-- missing values
select count(*) from dim_channel
    where channel_category is null;


-- duplicates check
select channel_id, count(*) from dim_channel
group by channel_id
having count(*) > 1;




/*
profiling the dim date table 
- primary key: date_id
one row meaning a date record (day) in date, the day order in the week, the number of the month, the name of the month, the number of the quarter
the year, the name of the day in the week, and if its a weekend or not
- there are no missing values in any of the dimensions
- no duplicate dates



*/

select * from dim_date 
limit 3;

-- missing values check
select count(*) 
from dim_date
where is_weekend is null


select * from dim_date 
limit 1;


-- duplicates check
select count(*), date_id from dim_date 
group by date_id
having count(*)>1;

-- date range check
select min(full_date), max(full_date)
from dim_date;



