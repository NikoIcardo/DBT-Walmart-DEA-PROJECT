{{ config(
    materialized='table'
) }}

select
    s.store_type,
    s.store_id,
    sum(f.store_weekly_sales) as total_weekly_sales
from {{ ref('walmart_fact_table') }} f
join {{ ref('walmart_store_dim') }} s 
    on f.store_id = s.store_id 
   and f.dept_id = s.dept_id
where f.vrsn_end_date is null
group by 
    s.store_type,
    s.store_id