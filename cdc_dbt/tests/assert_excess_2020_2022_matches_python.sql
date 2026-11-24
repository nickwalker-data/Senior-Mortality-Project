-- Cross-check the SQL baseline against the Python/statsmodels result:
-- total excess deaths 2020-2022 = 1,279,633 (with 2020's baseline scaled to 53 weeks).
-- Fails if they differ by more than 50 (small differences can come from rounding
-- expected deaths per row).
select total_excess
from (
    select sum(excess_deaths) as total_excess
    from {{ ref('fct_excess_deaths_by_age') }}
    where is_covid_period
)
where abs(total_excess - 1279633) > 50
