-- The map tab and the total tab should tell the same story: each year, the 51 states'
-- excess deaths should add up to the national 65+ excess. They can't match exactly:
-- state and national actuals differ by up to 0.05% (CDC rounding, see
-- assert_states_reconcile_to_national_65plus), and that gap carries into both the
-- actuals and the fitted baselines. Fails if they differ by more than 0.1% of 65+ deaths.
with by_year as (
    select
        death_year,
        sum(case when breakdown = 'Total 65+' then excess_deaths end) as national_excess,
        sum(case when breakdown = 'State'     then excess_deaths end) as states_excess,
        sum(case when breakdown = 'Total 65+' then actual_deaths end) as national_actual
    from {{ ref('mart_senior_dashboard') }}
    group by death_year
)

select
    death_year,
    national_excess,
    states_excess,
    states_excess - national_excess as diff
from by_year
where abs(states_excess - national_excess) > 0.001 * national_actual
