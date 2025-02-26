-- STATUS HISTORY
-- Analyzes procedure status and transition patterns
-- Used for tracking status changes and identifying potential workflow issues
-- dependent CTEs: BaseProcedures
StatusHistory AS (
    SELECT 
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcDate,
        pl.DateComplete,
        pl.AptNum,
        pl.ProcFee,
        pc.ProcCode,
        pc.Descript,
        CASE pl.ProcStatus
            WHEN 1 THEN 'Treatment Planned'
            WHEN 2 THEN 'Completed'
            WHEN 3 THEN 'Existing Current'
            WHEN 4 THEN 'Existing Other'
            WHEN 5 THEN 'Referred'
            WHEN 6 THEN 'Deleted'
            WHEN 7 THEN 'Condition'
            WHEN 8 THEN 'Invalid'
            ELSE 'Unknown'
        END AS status_description,
        -- Time in current status - FIXED with DATEDIFF for MariaDB compatibility
        CASE 
            WHEN pl.DateComplete IS NOT NULL THEN 
                DATEDIFF(CURRENT_DATE, pl.DateComplete) 
            ELSE 
                DATEDIFF(CURRENT_DATE, pl.ProcDate)
        END AS days_in_status,
        -- Identify expected transition patterns
        CASE
            -- Valid normal transitions
            WHEN pl.ProcStatus = 2 AND pl.DateComplete IS NOT NULL THEN 'Completed with date'
            WHEN pl.ProcStatus = 2 AND pl.DateComplete IS NULL THEN 'Completed missing date'
            WHEN pl.ProcStatus = 1 AND pl.DateComplete IS NULL THEN 'Planned (normal)'
            WHEN pl.ProcStatus = 1 AND pl.DateComplete IS NOT NULL THEN 'Planned with completion date'
            WHEN pl.ProcStatus = 6 AND pl.ProcFee = 0 THEN 'Deleted zero-fee'
            WHEN pl.ProcStatus = 6 AND pl.ProcFee > 0 THEN 'Deleted with fee'
            -- Terminal states
            WHEN pl.ProcStatus IN (3, 4, 5, 7) THEN 'Terminal status'
            ELSE 'Other pattern'
        END AS transition_pattern
    FROM BaseProcedures pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
)