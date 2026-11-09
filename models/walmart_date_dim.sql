{{ config(
    materialized='incremental',
    unique_key='date_id',
    incremental_strategy='merge'
) }}

with raw_fact as (
    select
        $2::date     as date_val,
        $12::boolean as is_holiday
    from '{{ source('s3_stage_source', '@WALMART_S3_STAGE/fact.csv') }}'
    where $2 != 'Date' and $2 is not null
),

-- Deduplicate dates and pick a single holiday status per date
deduped_dates as (
    select
        date_val,
        boolor_agg(is_holiday) as is_holiday
    from raw_fact
    group by date_val
),

staged_dates as (
    select
        to_number(to_char(date_val, 'YYYYMMDD')) as date_id,
        date_val                                 as date,
        is_holiday,
        current_timestamp()                      as insert_date,
        current_timestamp()                      as update_date
    from deduped_dates
)

select
    date_id,
    date,
    is_holiday,
    insert_date,
    update_date
from staged_dates