# Walmart Sales Analytics — dbt Project

A dbt project that turns raw Walmart sales CSVs, landed in Amazon S3, into a star schema in Snowflake and a set of report tables that power Tableau dashboards.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Source Data](#source-data)
4. [Data Model](#data-model)
5. [Report Models](#report-models)
6. [Snapshots](#snapshots)
7. [Getting Started](#getting-started)
8. [Running the Project](#running-the-project)
9. [Project Structure](#project-structure)
10. [Dashboards](#dashboards)
11. [Resources](#resources)

---

## Overview

| | |
|---|---|
| **Warehouse** | Snowflake (`WALMART_DEA_DB`) |
| **Raw storage** | Amazon S3, exposed through the external stage `WALMART_DEA_DB.RAW_LANDING.WALMART_S3_STAGE` |
| **Transformation** | dbt |
| **Visualization** | Tableau |
| **dbt project name** | `my_new_project` |
| **dbt profile** | `default` |

The pipeline reads three CSV files straight from the S3 stage. It builds two dimension tables and one fact table, then aggregates them into report tables for analysis by store, department, date, holiday, temperature, fuel price, CPI and promotional markdowns.

---

## Architecture

```
Amazon S3  (fact.csv, stores.csv, department.csv)
    │
    ▼
Snowflake external stage  WALMART_DEA_DB.RAW_LANDING.WALMART_S3_STAGE
    │
    ├──▶ Snapshot: walmart_fact_table_snapshot   (BRONZE schema, SCD Type 2)
    │
    ▼
Core models (incremental):  walmart_date_dim · walmart_store_dim · walmart_fact_table
    │
    ▼
Report models (tables):  rpt_*
    │
    ▼
Tableau dashboards
```

---

## Source Data

Sources are declared in [`models/sources.yml`](models/sources.yml) under the source name `s3_stage_source`. Each file is read with positional column references (`$1`, `$2`, …), and its header row is filtered out.

| Source table | Stage path | Contents |
|---|---|---|
| `fact_csv` | `@WALMART_DEA_DB.RAW_LANDING.WALMART_S3_STAGE/fact.csv` | Weekly store-level indicators: temperature, fuel price, markdowns 1–5, CPI, unemployment, holiday flag |
| `stores_csv` | `@WALMART_DEA_DB.RAW_LANDING.WALMART_S3_STAGE/stores.csv` | Store attributes: store ID, type, size |
| `department_csv` | `@WALMART_DEA_DB.RAW_LANDING.WALMART_S3_STAGE/department.csv` | Weekly sales by store and department |

**Data handling notes**

- Markdown values of `NA` are converted to `NULL`.
- Dates are turned into an integer surrogate key in `YYYYMMDD` format (`date_id`).

---

## Data Model

The core layer is a star schema. All three models are **incremental**, using the `merge` strategy.

```
                 ┌────────────────────┐
                 │  walmart_date_dim  │
                 │  PK: date_id       │
                 └─────────┬──────────┘
                           │
┌────────────────────┐     │     ┌──────────────────────────────┐
│ walmart_store_dim  │     │     │                              │
│ PK: store_id,      │─────┼─────│     walmart_fact_table       │
│     dept_id        │           │                              │
└────────────────────┘           └──────────────────────────────┘
```

### `walmart_date_dim`

One row per calendar date found in `fact.csv`.

| Column | Type | Description |
|---|---|---|
| `date_id` | number | Surrogate key (`YYYYMMDD`) — **unique key** |
| `date` | date | Calendar date |
| `is_holiday` | boolean | `TRUE` if any record for the date is flagged as a holiday |
| `insert_date` | timestamp | Load timestamp |
| `update_date` | timestamp | Last update timestamp |

### `walmart_store_dim`

One row per store–department combination.

| Column | Type | Description |
|---|---|---|
| `store_id` | integer | Store identifier — **unique key (with `dept_id`)** |
| `dept_id` | integer | Department identifier — **unique key (with `store_id`)** |
| `store_type` | varchar | Store type (A, B, C) |
| `store_size` | numeric | Store size |
| `insert_date` | timestamp | Load timestamp |
| `update_date` | timestamp | Last update timestamp |

### `walmart_fact_table`

One row per store, department and week. Built by joining `fact.csv` and `department.csv` on store and date, then adding store size from `stores.csv`.

| Column | Type | Description |
|---|---|---|
| `store_id` | integer | Store identifier |
| `dept_id` | integer | Department identifier |
| `date_id` | number | Foreign key to `walmart_date_dim` |
| `store_size` | numeric | Store size |
| `store_weekly_sales` | numeric | Weekly sales for the store and department |
| `fuel_price` | numeric | Regional fuel price |
| `temperature` | numeric | Average temperature |
| `unemployment` | numeric | Unemployment rate |
| `cpi` | numeric | Consumer Price Index |
| `markdown1` – `markdown5` | numeric | Promotional markdown amounts (`NULL` when not available) |
| `vrsn_start_date` | timestamp | Start of the record version |
| `vrsn_end_date` | timestamp | End of the record version; `NULL` for the current version |
| `insert_date` | timestamp | Load timestamp |
| `update_date` | timestamp | Last update timestamp |

**Unique key:** `store_id`, `dept_id`, `date_id`, `vrsn_start_date`

---

## Report Models

Report models are materialized as **tables**. They read only the current fact records (`vrsn_end_date IS NULL`) and are shaped for Tableau.

| Model | Grain | Metrics |
|---|---|---|
| [`rpt_sales_by_department`](models/rpt_sales_by_department.sql) | Department | Total weekly sales |
| [`rpt_sales_by_store_holiday`](models/rpt_sales_by_store_holiday.sql) | Store | Non-holiday sales, holiday sales |
| [`rpt_sales_by_store_size`](models/rpt_sales_by_store_size.sql) | Store, store size | Total weekly sales |
| [`rpt_sales_by_store_type`](models/rpt_sales_by_store_type.sql) | Store type, store | Total weekly sales |
| [`rpt_sales_by_store_type_and_month`](models/rpt_sales_by_store_type_and_month.sql) | Month, store type | Total weekly sales |
| [`rpt_sales_by_year_month_date`](models/rpt_sales_by_year_month_date.sql) | Year, month, day | Total weekly sales |
| [`rpt_sales_by_temp_and_year`](models/rpt_sales_by_temp_and_year.sql) | Year, temperature | Total weekly sales (every year × temperature pair, with `NULL` where there are no sales) |
| [`rpt_sales_by_cpi`](models/rpt_sales_by_cpi.sql) | CPI (rounded to 2 dp) | Total weekly sales |
| [`rpt_fuel_price_by_year`](models/rpt_fuel_price_by_year.sql) | Store, year | Total and average fuel price |
| [`rpt_markdown_sales_by_year_and_store`](models/rpt_markdown_sales_by_year_and_store.sql) | Year, store | Totals for markdowns 1–5 |

---

## Snapshots

### `walmart_fact_table_snapshot`

Defined in [`snapshots/walmart_fact_table_snapshot.sql`](snapshots/walmart_fact_table_snapshot.sql), this snapshot keeps a Slowly Changing Dimension Type 2 history of the fact data.

| Setting | Value |
|---|---|
| Target | `WALMART_DEA_DB.BRONZE` |
| Unique key | `store_id-dept_id-date_id` |
| Strategy | `check` |
| Checked columns | `store_size`, `store_weekly_sales`, `fuel_price`, `temperature`, `unemployment`, `cpi`, `markdown1`–`markdown5` |
| Hard deletes | Invalidated (`invalidate_hard_deletes=True`) |

---

## Getting Started

### Prerequisites

- A Snowflake account with access to `WALMART_DEA_DB`
- The S3 files loaded and reachable through `RAW_LANDING.WALMART_S3_STAGE`

### Installation

```bash
git clone <repository-url>
cd DBT-Walmart-DEA-PROJECT
```

### Configure the Snowflake profile

The project uses the `default` profile. Add it to `~/.dbt/profiles.yml`:

```yaml
default:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <account_identifier>
      user: <username>
      password: <password>
      role: <role>
      warehouse: <warehouse>
      database: WALMART_DEA_DB
      schema: <target_schema>
      threads: 4
```

Check the connection:

```bash
dbt debug
```

---

## Running the Project

| Task | Command |
|---|---|
| Build every model | `dbt run` |
| Build the core star schema only | `dbt run --select walmart_date_dim walmart_store_dim walmart_fact_table` |
| Build the report tables only | `dbt run --select rpt_*` |
| Fully rebuild incremental models | `dbt run --full-refresh` |
| Capture fact table history | `dbt snapshot` |
| Run tests | `dbt test` |
| Run models, tests and snapshots together | `dbt build` |
| Generate and serve documentation | `dbt docs generate && dbt docs serve` |

---

## Project Structure

```
DBT-Walmart-DEA-PROJECT/
├── dbt_project.yml                 # dbt project configuration
├── models/
│   ├── sources.yml                 # S3 stage source definitions
│   ├── walmart_date_dim.sql        # Date dimension
│   ├── walmart_store_dim.sql       # Store/department dimension
│   ├── walmart_fact_table.sql      # Sales fact table
│   ├── rpt_*.sql                   # Report tables for Tableau
│   └── example/                    # dbt starter models (not part of the pipeline)
├── snapshots/
│   └── walmart_fact_table_snapshot.sql
├── report screenshots/             # Tableau dashboard screenshots
├── analyses/
├── macros/
├── seeds/
└── tests/
```

---

## Dashboards

The report tables feed the Tableau dashboards below.

### Weekly Sales by Department
![Department wise weekly sales](report%20screenshots/Department%20wise%20weekly%20sales.png)

### Weekly Sales by Store and Holiday
![Weekly sales by store and holiday](report%20screenshots/weekly%20sales%20by%20store%20and%20holiday.png)

### Weekly Sales by Store Size
![Weekly sales by store size](report%20screenshots/Weekly%20Sales%20By%20Store%20Size.png)

### Weekly Sales by Store Type
![Weekly sales by store type](report%20screenshots/weekly%20sales%20by%20store%20type.png)

### Weekly Sales by Store Type and Month
![Weekly sales by store type and month](report%20screenshots/Weekly%20Sales%20By%20Store%20Type%20And%20Month.png)

### Weekly Sales by Year
![Weekly sales by year](report%20screenshots/Weekly%20Sales%20by%20Year.png)

### Weekly Sales by Month
![Weekly sales by month](report%20screenshots/weekly%20sales%20by%20month.png)

### Weekly Sales by Date
![Weekly sales by date](report%20screenshots/weekly%20sales%20by%20date.png)

### Weekly Sales by Temperature and Year
![Weekly sales by temperature and year](report%20screenshots/Weekly%20sales%20by%20temperature%20and%20year.png)

### Weekly Sales by CPI
![Weekly sales by CPI](report%20screenshots/weekly%20sales%20by%20cpi.png)

### Fuel Price by Year
![Fuel price by year](report%20screenshots/fuel%20price%20by%20year.png)

### Markdown Sales by Year and Store
![Markdown sales by year and store](report%20screenshots/Markdown%20sales%20by%20year%20and%20store.png)

---

## Resources

- [dbt documentation](https://docs.getdbt.com/docs/introduction)
- [dbt-snowflake adapter](https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup)
- [dbt snapshots](https://docs.getdbt.com/docs/build/snapshots)
- [Snowflake: querying staged files](https://docs.snowflake.com/en/user-guide/querying-stage)
