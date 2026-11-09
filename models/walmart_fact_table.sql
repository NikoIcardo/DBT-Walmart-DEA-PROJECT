{{ config(
    materialized='incremental',
    unique_key=['store_id', 'dept_id', 'date_id', 'vrsn_start_date'],
    incremental_strategy='merge'
) }}

with raw_fact as (
    select
        $1::integer   as store_id,
        $2::date      as sales_date,
        $3::numeric   as temperature,
        $4::numeric   as fuel_price,
        $5::varchar   as markdown1,
        $6::varchar   as markdown2,
        $7::varchar   as markdown3,
        $8::varchar   as markdown4,
        $9::varchar   as markdown5,
        $10::numeric  as cpi,
        $11::numeric  as unemployment
    from '{{ source('s3_stage_source', '@WALMART_S3_STAGE/fact.csv') }}'
    where $1 != 'Store' and $1 is not null
),

raw_department as (
    select
        $1::integer as store_id,
        $2::integer as dept_id,
        $3::numeric as weekly_sales
    from '{{ source('s3_stage_source', '@WALMART_S3_STAGE/department.csv') }}'
    where $1 != 'Store' and $1 is not null
),

raw_stores as (
    select
        $1::integer as store_id,
        $3::numeric as store_size
    from '{{ source('s3_stage_source', '@WALMART_S3_STAGE/stores.csv') }}'
    where $1 != 'Store' and $1 is not null
),

joined_sources as (
    select
        f.store_id,
        d.dept_id,
        to_number(to_char(f.sales_date, 'YYYYMMDD')) as date_id,
        s.store_size,
        d.weekly_sales                              as store_weekly_sales,
        f.fuel_price,
        f.temperature,
        f.unemployment,
        f.cpi,
        nullif(f.markdown1, 'NA')::numeric          as markdown1,
        nullif(f.markdown2, 'NA')::numeric          as markdown2,
        nullif(f.markdown3, 'NA')::numeric          as markdown3,
        nullif(f.markdown4, 'NA')::numeric          as markdown4,
        nullif(f.markdown5, 'NA')::numeric          as markdown5
    from raw_fact f
    inner join raw_department d
        on f.store_id = d.store_id
    left join raw_stores s
        on f.store_id = s.store_id
),

scd2_staged as (
    select
        store_id,
        dept_id,
        date_id,
        store_size,
        store_weekly_sales,
        fuel_price,
        temperature,
        unemployment,
        cpi,
        markdown1,
        markdown2,
        markdown3,
        markdown4,
        markdown5,
        current_timestamp() as vrsn_start_date,
        cast(null as timestamp_ntz) as vrsn_end_date,
        current_timestamp() as insert_date,
        current_timestamp() as update_date
    from joined_sources
)

select
    store_id,
    dept_id,
    date_id,
    store_size,
    store_weekly_sales,
    fuel_price,
    temperature,
    unemployment,
    cpi,
    markdown1,
    markdown2,
    markdown3,
    markdown4,
    markdown5,
    vrsn_start_date,
    vrsn_end_date,
    insert_date,
    update_date
from scd2_staged