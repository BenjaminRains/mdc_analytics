-- Set date range variables to ensure consistency
-- Dependencies: @start_date and @end_date from script
DateRange AS (
    SELECT 
        @start_date as start_date,
        @end_date as end_date
)