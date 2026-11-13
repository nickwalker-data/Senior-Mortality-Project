-- Validation against a known CDC figure: 2015, ages 25-44 = 124,889 deaths.
-- Returns a row (test fails) if the loaded data does not match.
select *
from {{ ref('stg_us_deaths_by_age_year') }}
where death_year = 2015
  and age_group = '25-44'
  and deaths != 124889
