-- Shape check on the dashboard mart: each year has 1 total row, 3 age-group rows and
-- 51 state rows, across all 8 years (2015-2022) = 440 rows. Fails on gaps or duplicates,
-- and on any year outside 2015-2022 (e.g. a re-pull that adds partial 2023).
with counts as (
    select breakdown, death_year, count(*) as n
    from {{ ref('mart_senior_dashboard') }}
    group by breakdown, death_year
)

select breakdown, death_year, n
from counts
where n != case breakdown
               when 'Total 65+' then 1
               when 'Age group' then 3
               when 'State'     then 51
           end

union all

select breakdown, null, count(*)
from counts
group by breakdown
having count(*) != 8

union all

select 'year range', null, count(*)
from {{ ref('mart_senior_dashboard') }}
where death_year not between 2015 and 2022
having count(*) > 0
