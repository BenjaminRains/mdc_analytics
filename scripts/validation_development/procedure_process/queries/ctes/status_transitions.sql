-- Description: Status transition patterns with more context
-- Dependent CTEs: date_params.sql, status_7_base.sql
-- Date range: 2024-01-01 to 2025-01-01

StatusTransitions AS (
    SELECT 
        s7.ProcNum,
        s7.PatNum,
        s7.CodeNum,
        s7.ProcCode,
        s7.ProcCat,
        s7.ProcDate as status_7_date,
        s7.has_treatment_plan,
        s7.treatment_plan_date,
        s7.has_appointment,
        s7.appointment_date,
        s7.volume_flag,
        -- Look for related procedures within 30 days
        GROUP_CONCAT(DISTINCT 
            CONCAT(
                pl_near.ProcStatus, ':', 
                DATEDIFF(pl_near.ProcDate, s7.ProcDate), ':',
                CASE WHEN tpa_near.TreatPlanAttachNum IS NOT NULL THEN 'P' ELSE 'N' END, ':',
                CASE WHEN apt_near.AptNum IS NOT NULL THEN 'A' ELSE 'N' END
            )
            ORDER BY pl_near.ProcDate
        ) as nearby_status_changes
    FROM Status7Base s7
    LEFT JOIN procedurelog pl_near ON s7.PatNum = pl_near.PatNum 
        AND s7.CodeNum = pl_near.CodeNum
        AND pl_near.ProcStatus != 7
        AND ABS(DATEDIFF(pl_near.ProcDate, s7.ProcDate)) <= 30
        AND pl_near.ProcDate >= (SELECT start_date FROM DateParams)
        AND pl_near.ProcDate < (SELECT end_date FROM DateParams)
    LEFT JOIN treatplanattach tpa_near ON pl_near.ProcNum = tpa_near.ProcNum
    LEFT JOIN appointment apt_near ON pl_near.AptNum = apt_near.AptNum
    GROUP BY s7.ProcNum, s7.PatNum, s7.CodeNum, s7.ProcCode, s7.ProcCat, 
             s7.ProcDate, s7.has_treatment_plan, s7.treatment_plan_date,
             s7.has_appointment, s7.appointment_date, s7.volume_flag
)