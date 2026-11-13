-- One row per year and age group, with clean names and types.
select
    cast(Year as int64)                      as death_year,
    AgeGroup                                 as age_group,
    cast(Deaths as int64)                    as deaths,
    concat(cast(Year as string), '|', AgeGroup) as year_age_key
from {{ source('cdc', 'us_deaths_by_age_year') }}
