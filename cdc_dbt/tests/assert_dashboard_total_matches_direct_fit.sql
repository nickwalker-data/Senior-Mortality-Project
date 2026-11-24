-- The mart builds the 65+ total by adding up three age groups' trend lines.
-- This fits one trend directly on total 65+ deaths and checks they agree:
-- actual deaths must match exactly; expected within 2 deaths (each age group's
-- expected value is rounded before the sum, so up to 3 x 0.5 of drift).
-- Uses the same 52/53-week adjustment as the fct_ marts.
with seniors as (
    select
        d.death_year,
        w.weeks_in_year,
        sum(d.deaths)                                    as deaths_65_plus,
        sum(d.deaths) * 52 / w.weeks_in_year             as deaths_52wk
    from {{ ref('stg_us_deaths_by_age_year') }} d
    join {{ ref('cdc_weeks_per_year') }} w using (death_year)
    where d.age_group in ('65-74', '75-84', '85 and older')
    group by d.death_year, w.weeks_in_year
),

fit as (
    select
        covar_pop(death_year, deaths_52wk) / var_pop(death_year)                  as slope,
        avg(deaths_52wk) - covar_pop(death_year, deaths_52wk) / var_pop(death_year)
            * avg(death_year)                                                     as intercept
    from seniors
    where death_year between 2015 and 2019
),

direct as (
    select
        s.death_year,
        s.deaths_65_plus,
        (f.intercept + f.slope * s.death_year) * s.weeks_in_year / 52             as expected_direct
    from seniors s
    cross join fit f
),

mart as (
    select death_year, actual_deaths, expected_deaths
    from {{ ref('mart_senior_dashboard') }}
    where breakdown = 'Total 65+'
)

select
    d.death_year,
    m.actual_deaths,
    d.deaths_65_plus,
    m.expected_deaths,
    round(d.expected_direct, 1) as expected_direct
from direct d
join mart m using (death_year)
where m.actual_deaths != d.deaths_65_plus
   or abs(m.expected_deaths - d.expected_direct) > 2
