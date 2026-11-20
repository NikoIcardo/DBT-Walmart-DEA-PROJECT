{{ config(
    materialized='table'
) }}

select
    f.store_id,
    extract(year from d.date)        as sales_year,
    sum(f.fuel_price)                as total_fuel_price,
    avg(f.fuel_price)                as avg_fuel_price
from {{ ref('walmart_fact_table') }} f
join {{ ref('walmart_date_dim') }} d 
    on f.date_id = d.date_id
where f.vrsn_end_date is null
group by 
    1, 2