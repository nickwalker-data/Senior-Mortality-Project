-- Excess deaths by age group and year, measured against a 2015-2019 linear trend.
-- Note: the CTE is named 'yearly' (not 'deaths') because BigQuery would read
-- a bare 'deaths' as the whole table row instead of the column.
-- Rebuilds the statsmodels OLS baseline from cdc_trend_analysis.py in SQL:
--   slope = covariance(year, deaths) / variance(year), fit on 2015-2019 only
--   intercept = avg(deaths) - slope * avg(year)
with yearly as (
    select death_year, age_group, deaths
    from {{ ref('stg_us_deaths_by_age_year') }}
),

baseline_fit as (
    select
        age_group,
        covar_pop(death_year, deaths) / var_pop(death_year)               as slope_per_year,
        avg(deaths) - covar_pop(death_year, deaths) / var_pop(death_year)
            * avg(death_year)                                              as intercept,
        power(corr(death_year, deaths), 2)                                 as r2_2015_2019
    from yearly
    where death_year between 2015 and 2019
    group by age_group
)

select
    d.death_year,
    d.age_group,
    d.deaths,
    round(b.intercept + b.slope_per_year * d.death_year)                  as expected_deaths,
    d.deaths - round(b.intercept + b.slope_per_year * d.death_year)       as excess_deaths,
    round(100 * (d.deaths / (b.intercept + b.slope_per_year * d.death_year) - 1), 1)
                                                                          as pct_above_expected,
    round(b.slope_per_year)                                               as slope_per_year,
    round(b.r2_2015_2019, 3)                                              as r2_2015_2019,
    d.death_year >= 2020                                                  as is_covid_period
from yearly d
join baseline_fit b using (age_group)
