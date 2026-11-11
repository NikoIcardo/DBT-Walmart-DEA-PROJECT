{{ config(
    materialized='table'
) }}

select
    extract(year from d.date)        as sales_year,
    round(f.temperature, 2)         as temp_binned,
    sum(f.store_weekly_sales)        as total_weekly_sales
from {{ ref('walmart_fact_table') }} f
join {{ ref('walmart_date_dim') }} d 
    on f.date_id = d.date_id
where f.vrsn_end_date is null
group by 
    1, 2