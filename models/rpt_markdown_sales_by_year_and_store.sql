{{ config(
    materialized='table'
) }}

select
    extract(year from d.date)        as sales_year,
    f.store_id,
    sum(coalesce(f.markdown1, 0))    as total_markdown1,
    sum(coalesce(f.markdown2, 0))    as total_markdown2,
    sum(coalesce(f.markdown3, 0))    as total_markdown3,
    sum(coalesce(f.markdown4, 0))    as total_markdown4,
    sum(coalesce(f.markdown5, 0))    as total_markdown5
from {{ ref('walmart_fact_table') }} f
join {{ ref('walmart_date_dim') }} d 
    on f.date_id = d.date_id
where f.vrsn_end_date is null
group by 
    1, 2