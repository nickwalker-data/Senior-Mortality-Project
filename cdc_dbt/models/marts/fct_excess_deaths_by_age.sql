-- Excess deaths by age group and year, measured against a 2015-2019 linear trend.
-- Note: the CTE is named 'yearly' (not 'deaths') because BigQuery would read
-- a bare 'deaths' as the whole table row instead of the column.
-- Rebuilds the statsmodels OLS baseline from cdc_trend_analysis.py in SQL:
--   slope = covariance(year, deaths) / variance(year), fit on 2015-2019 only
--   intercept = avg(deaths) - slope * avg(year)
-- Week adjustment: CDC years run 52 or 53 weeks (2020 has 53). The trend is fit on deaths
-- scaled to a 52-week basis, and expected deaths are scaled back to each year's week count,
-- so a 53-week year is compared with 53 weeks of expected deaths. weeks_in_year is counted
-- from the CDC data by cdc_mortality_pull.py (seeds/cdc_weeks_per_year.csv).
with yearly as (
    select
        d.death_year,
        d.age_group,
        d.deaths,
        w.weeks_in_year,
        d.deaths * 52 / w.weeks_in_year                                   as deaths_52wk
    from {{ ref('stg_us_deaths_by_age_year') }} d
    left join {{ ref('cdc_weeks_per_year') }} w using (death_year)   -- left join: a missing year fails the not_null test instead of vanishing
),

baseline_fit as (
    select
        age_group,
        covar_pop(death_year, deaths_52wk) / var_pop(death_year)          as slope_per_year,
        avg(deaths_52wk) - covar_pop(death_year, deaths_52wk) / var_pop(death_year)
            * avg(death_year)                                              as intercept,
        power(corr(death_year, deaths_52wk), 2)                            as r2_2015_2019
    from yearly
    where death_year between 2015 and 2019
    group by age_group
),

projected as (
    select
        y.death_year,
        y.age_group,
        y.deaths,
        y.weeks_in_year,
        (b.intercept + b.slope_per_year * y.death_year) * y.weeks_in_year / 52  as expected_raw,
        b.slope_per_year,
        b.r2_2015_2019
    from yearly y
    join baseline_fit b using (age_group)
)

select
    death_year,
    age_group,
    deaths,
    weeks_in_year,
    round(expected_raw)                                                   as expected_deaths,
    deaths - round(expected_raw)                                          as excess_deaths,
    round(100 * (deaths / expected_raw - 1), 1)                           as pct_above_expected,
    round(slope_per_year)                                                 as slope_per_year,
    round(r2_2015_2019, 3)                                                as r2_2015_2019,
    death_year >= 2020                                                    as is_covid_period
from projected
