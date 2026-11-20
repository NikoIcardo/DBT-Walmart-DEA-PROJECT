{{ config(materialized='table')}}


select 
    wft.store_id, 
    sum(
        case 
            when wdd.is_Holiday = false then wft.store_weekly_sales
            else 0
        end
    ) as total_weekly_sales,
    sum(
        case 
            when wdd.is_Holiday = true then wft.store_weekly_sales
            else 0
        end
    ) as total_holiday_sales
from 
    {{ref('walmart_fact_table')}} wft
join
    {{ref('walmart_date_dim')}} wdd
on 
    wft.date_id = wdd.date_id
where 
    wft.vrsn_end_date is null
group by 
    wft.store_id
