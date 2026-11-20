{{ config(
    materialized='table'
) }}

with base_sales as (
    select
        extract(year from d.date)        as sales_year,
        round(f.temperature, 2)          as temp_binned,
        sum(f.store_weekly_sales)        as total_weekly_sales
    from {{ ref('walmart_fact_table') }} f
    join {{ ref('walmart_date_dim') }} d 
        on f.date_id = d.date_id
    where f.vrsn_end_date is null
    group by 
        1, 2
),

all_temps as (
    select distinct temp_binned from base_sales
),

all_years as (
    select distinct sales_year from base_sales
)

select
    y.sales_year,
    t.temp_binned,
    b.total_weekly_sales
from all_temps t
cross join all_years y
left join base_sales b
    on t.temp_binned = b.temp_binned
    and y.sales_year = b.sales_year