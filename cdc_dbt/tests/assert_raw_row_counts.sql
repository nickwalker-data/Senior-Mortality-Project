-- Completeness check on the raw load: 6 age groups x 8 years = 48 national rows,
-- 51 jurisdictions x 8 years = 408 state rows. Fails if a reload drops or duplicates rows.
select 'us_deaths_by_age_year' as source_table, count(*) as row_count, 48 as expected
from {{ source('cdc', 'us_deaths_by_age_year') }}
having count(*) != 48

union all

select 'state_deaths_65plus', count(*), 408
from {{ source('cdc', 'state_deaths_65plus') }}
having count(*) != 408
