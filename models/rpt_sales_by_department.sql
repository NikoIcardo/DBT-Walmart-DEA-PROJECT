{{ config(
    materialized='table'
) }}

select
    f.dept_id,
    sum(f.store_weekly_sales) as total_weekly_sales
from {{ ref('walmart_fact_table') }} f
where f.vrsn_end_date is null
group by 
    1