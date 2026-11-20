{{ config(
    materialized='table'
) }}

select
    extract(month from d.date)        as month_num,
    to_char(d.date, 'MMMM')           as month_name,
    s.store_type,
    sum(f.store_weekly_sales)        as total_weekly_sales
from {{ ref('walmart_fact_table') }} f
join {{ ref('walmart_date_dim') }} d 
    on f.date_id = d.date_id
join {{ ref('walmart_store_dim') }} s 
    on f.store_id = s.store_id 
   and f.dept_id = s.dept_id
where f.vrsn_end_date is null
group by 
    1, 2, 3