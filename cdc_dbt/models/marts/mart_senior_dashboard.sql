-- Dashboard-shaped mart for the Tableau Public dashboard: one CSV feeds all three tabs.
-- Long format, one row per year x breakdown x category:
--   breakdown = 'Total 65+'  -> tab 1: actual vs expected deaths, all seniors
--   breakdown = 'Age group'  -> tab 2: 65-74, 75-84, 85+
--   breakdown = 'State'      -> tab 3: state map, 50 states + DC
-- No new trend logic: expected deaths come from the two existing marts.
-- The 65+ total adds up the three age groups' expected deaths. That is valid because a
-- straight-line fit of a sum equals the sum of the fits (checked by
-- assert_dashboard_total_matches_direct_fit). Its % above expected is recomputed from
-- the sums, never averaged.
with senior_ages as (
    select
        death_year,
        case age_group when '85 and older' then '85+' else age_group end as category,
        case age_group when '65-74' then 1 when '75-84' then 2 else 3 end as sort_order,
        weeks_in_year,
        deaths,
        expected_deaths,
        pct_above_expected,
        r2_2015_2019
    from {{ ref('fct_excess_deaths_by_age') }}
    where age_group in ('65-74', '75-84', '85 and older')
),

unioned as (
    -- Tab 1: all seniors combined
    select
        death_year,
        'Total 65+'                                                   as breakdown,
        '65+'                                                         as category,
        cast(null as string)                                          as state_code,
        any_value(weeks_in_year)                                      as weeks_in_year,
        sum(deaths)                                                   as actual_deaths,
        sum(expected_deaths)                                          as expected_deaths,
        round(100 * (sum(deaths) / sum(expected_deaths) - 1), 1)      as pct_above_expected,
        cast(null as float64)                                         as r2_2015_2019,
        cast(null as int64)                                           as rank_within_year,
        0                                                             as sort_order
    from senior_ages
    group by death_year

    union all

    -- Tab 2: one row per senior age group
    select
        death_year, 'Age group', category, null, weeks_in_year,
        deaths, expected_deaths, pct_above_expected, r2_2015_2019,
        null, sort_order
    from senior_ages

    union all

    -- Tab 3: one row per state (category = full name, state_code for Tableau's map role)
    select
        death_year, 'State', state_name, state_code, weeks_in_year,
        deaths_65_plus, expected_deaths, pct_above_expected, r2_2015_2019,
        rank_within_year, null
    from {{ ref('fct_state_65plus_excess') }}
)

select
    concat(breakdown, '|', coalesce(state_code, category), '|', cast(death_year as string))
                                                    as dashboard_key,
    death_year,
    breakdown,
    category,
    state_code,
    weeks_in_year,
    cast(actual_deaths as int64)                    as actual_deaths,
    cast(expected_deaths as int64)                  as expected_deaths,
    cast(actual_deaths - expected_deaths as int64)  as excess_deaths,
    pct_above_expected,
    r2_2015_2019,
    rank_within_year,
    death_year >= 2020                              as is_covid_period,
    sort_order
from unioned
