-- Excess deaths age 65+ by state and year, against each state's own 2015-2019 linear trend.
-- Same method as fct_excess_deaths_by_age, applied per state instead of per age group.
with state_year as (
    select state_code, state_name, death_year, deaths_65_plus
    from {{ ref('stg_state_deaths_65plus') }}
),

baseline_fit as (
    select
        state_code,
        covar_pop(death_year, deaths_65_plus) / var_pop(death_year)                as slope_per_year,
        avg(deaths_65_plus) - covar_pop(death_year, deaths_65_plus) / var_pop(death_year)
            * avg(death_year)                                                       as intercept,
        power(corr(death_year, deaths_65_plus), 2)                                  as r2_2015_2019
    from state_year
    where death_year between 2015 and 2019
    group by state_code
),

scored as (
    select
        s.state_code,
        s.state_name,
        s.death_year,
        s.deaths_65_plus,
        round(b.intercept + b.slope_per_year * s.death_year)                        as expected_deaths,
        s.deaths_65_plus - round(b.intercept + b.slope_per_year * s.death_year)     as excess_deaths,
        round(100 * (s.deaths_65_plus / (b.intercept + b.slope_per_year * s.death_year) - 1), 1)
                                                                                    as pct_above_expected,
        round(b.r2_2015_2019, 3)                                                    as r2_2015_2019,
        concat(s.state_code, '|', cast(s.death_year as string))                     as state_year_key
    from state_year s
    join baseline_fit b using (state_code)
)

select
    *,
    -- 1 = highest % above trend among the 51 jurisdictions that year
    rank() over (partition by death_year order by pct_above_expected desc)          as rank_within_year
from scored
