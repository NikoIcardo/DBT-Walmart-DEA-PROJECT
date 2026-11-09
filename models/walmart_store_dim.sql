{{ config(
    materialized='incremental',
    unique_key=['store_id', 'dept_id'],
    incremental_strategy='merge'
) }}

with stores as (
    select distinct
        $1::integer as store_id,
        $2::varchar as store_type,
        $3::numeric as store_size
    from '{{ source('s3_stage_source', '@WALMART_S3_STAGE/stores.csv') }}'
    where $1 != 'Store' and $1 is not null
),

departments as (
    select distinct
        $1::integer as store_id,   
        $2::integer as dept_id     
    from '{{ source('s3_stage_source', '@WALMART_S3_STAGE/department.csv') }}'
    where $1 != 'Store' and $1 is not null
),

joined_store_dept as (
    select distinct
        s.store_id,
        d.dept_id,
        s.store_type,
        s.store_size
    from stores s
    inner join departments d
        on s.store_id = d.store_id
),

final_staged as (
    select
        store_id,
        dept_id,
        store_type,
        store_size,
        current_timestamp() as insert_date,
        current_timestamp() as update_date
    from joined_store_dept
)

select
    store_id,
    dept_id,
    store_type,
    store_size,
    insert_date,
    update_date
from final_staged