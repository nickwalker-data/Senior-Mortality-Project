-- Reconciliation: the 51 jurisdictions' 65+ deaths should add up to the national 65+ total.
-- They differ slightly (about 0.01%) because CDC rounds weighted estimates per state and week,
-- so this fails only if any year is off by more than 0.05%.
with national as (
    select death_year, sum(deaths) as national_65_plus
    from {{ ref('stg_us_deaths_by_age_year') }}
    where age_group in ('65-74', '75-84', '85 and older')
    group by death_year
),

states as (
    select death_year, sum(deaths_65_plus) as states_65_plus, count(*) as n_states
    from {{ ref('stg_state_deaths_65plus') }}
    group by death_year
)

select
    n.death_year,
    n.national_65_plus,
    s.states_65_plus,
    s.n_states,
    round(100 * (s.states_65_plus - n.national_65_plus) / n.national_65_plus, 4) as pct_diff
from national n
join states s using (death_year)
where abs(s.states_65_plus - n.national_65_plus) / n.national_65_plus > 0.0005
   or s.n_states != 51
