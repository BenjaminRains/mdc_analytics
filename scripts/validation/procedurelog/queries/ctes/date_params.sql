-- Date parameters CTE
-- Date filter: 2024-01-01 to 2025-01-01
-- This CTE provides standardized date filtering across queries
-- Dependent CTEs:

DateParams AS (
    SELECT 
        '{{START_DATE}}' as start_date,
        '{{END_DATE}}' as end_date
) 