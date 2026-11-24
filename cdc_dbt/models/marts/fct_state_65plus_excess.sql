-- Excess deaths age 65+ by state and year, against each state's own 2015-2019 linear trend.
-- Same method as fct_excess_deaths_by_age, applied per state instead of per age group,
-- including the 52/53-week adjustment (trend fit on a 52-week basis, expected deaths
-- scaled to each year's week count from seeds/cdc_weeks_per_year.csv).
with state_year as (
    select
        s.state_code,
        s.state_name,
        s.death_year,
        s.deaths_65_plus,
        w.weeks_in_year,
        s.deaths_65_plus * 52 / w.weeks_in_year                                     as deaths_52wk
    from {{ ref('stg_state_deaths_65plus') }} s
    left join {{ ref('cdc_weeks_per_year') }} w using (death_year)
),

baseline_fit as (
    select
        state_code,
        covar_pop(death_year, deaths_52wk) / var_pop(death_year)                    as slope_per_year,
        avg(deaths_52wk) - covar_pop(death_year, deaths_52wk) / var_pop(death_year)
            * avg(death_year)                                                       as intercept,
        power(corr(death_year, deaths_52wk), 2)                                     as r2_2015_2019
    from state_year
    where death_year between 2015 and 2019
    group by state_code
),

projected as (
    select
        s.state_code,
        s.state_name,
        s.death_year,
        s.deaths_65_plus,
        s.weeks_in_year,
        (b.intercept + b.slope_per_year * s.death_year) * s.weeks_in_year / 52      as expected_raw,
        b.r2_2015_2019
    from state_year s
    join baseline_fit b using (state_code)
),

scored as (
    select
        state_code,
        state_name,
        death_year,
        deaths_65_plus,
        weeks_in_year,
        round(expected_raw)                                                         as expected_deaths,
        deaths_65_plus - round(expected_raw)                                        as excess_deaths,
        round(100 * (deaths_65_plus / expected_raw - 1), 1)                         as pct_above_expected,
        round(r2_2015_2019, 3)                                                      as r2_2015_2019,
        concat(state_code, '|', cast(death_year as string))                         as state_year_key
    from projected
)

select
    *,
    -- 1 = highest % above trend among the 51 jurisdictions that year
    rank() over (partition by death_year order by pct_above_expected desc)          as rank_within_year
from scored
