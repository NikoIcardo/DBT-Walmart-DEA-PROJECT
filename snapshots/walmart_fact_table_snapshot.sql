{% snapshot walmart_fact_table_snapshot %}

{{
    config(
      target_database='WALMART_DEA_DB',
      target_schema='BRONZE',
      unique_key='store_id || "-" || dept_id || "-" || date_id',
      strategy='check',
      check_cols=[
          'store_size',
          'store_weekly_sales',
          'fuel_price',
          'temperature',
          'unemployment',
          'cpi',
          'markdown1',
          'markdown2',
          'markdown3',
          'markdown4',
          'markdown5'
      ],
      invalidate_hard_deletes=True
    )
}}

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
    from '@WALMART_DEA_DB.RAW_LANDING.WALMART_S3_STAGE/fact.csv'
    where $1 != 'Store' and $1 is not null
),

raw_department as (
    select
        $1::integer as store_id,
        $2::integer as dept_id,
        $3::date    as sales_date,
        $4::numeric as weekly_sales
    from '@WALMART_DEA_DB.RAW_LANDING.WALMART_S3_STAGE/department.csv'
    where $1 != 'Store' and $1 is not null
),

raw_stores as (
    select
        $1::integer as store_id,
        $3::numeric as store_size
    from '@WALMART_DEA_DB.RAW_LANDING.WALMART_S3_STAGE/stores.csv'
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
       and f.sales_date = d.sales_date
    left join raw_stores s
        on f.store_id = s.store_id
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
    markdown5
from joined_sources

{% endsnapshot %}