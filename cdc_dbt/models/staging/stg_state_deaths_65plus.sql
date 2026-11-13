-- One row per state and year, with clean names and types.
select
    State                                    as state_code,
    StateName                                as state_name,
    cast(Year as int64)                      as death_year,
    cast(Deaths65Plus as int64)              as deaths_65_plus,
    concat(State, '|', cast(Year as string)) as state_year_key
from {{ source('cdc', 'state_deaths_65plus') }}
