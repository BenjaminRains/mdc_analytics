-- Set date range variables to ensure consistency
-- Date range: @start_date to @end_date
-- Dependencies:
WITH DateRange AS (
    SELECT 
        @start_date as start_date,
        @end_date as end_date
)