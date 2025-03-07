WITH JanuaryPatients AS (
    -- Get all patients seen in December 2024
    SELECT DISTINCT 
        p.PatNum,
        p.LName,
        p.FName,
        p.Preferred,
        p.HmPhone,
        p.WkPhone,
        p.WirelessPhone,
        p.Email,
        p.PatStatus,
        MAX(a.AptDateTime) as LastJanuaryApt
    FROM patient p
    JOIN appointment a ON p.PatNum = a.PatNum
    WHERE a.AptDateTime >= '2024-12-01'
    AND a.AptDateTime < '2025-01-01'
    AND a.AptStatus = 2  -- Completed
    GROUP BY p.PatNum, p.LName, p.FName, p.Preferred, p.HmPhone, p.WkPhone, p.WirelessPhone, p.Email, p.PatStatus
),
PlannedTreatments AS (
    -- Get detailed treatment plan information
    SELECT 
        pl.PatNum,
        COUNT(*) as PlannedProcCount,
        GROUP_CONCAT(DISTINCT pd.ProcCode) as PlannedProcCodes,
        GROUP_CONCAT(DISTINCT pd.Descript SEPARATOR ' | ') as ProcedureDescriptions,
        MIN(pl.ProcDate) as EarliestPlannedDate,
        GROUP_CONCAT(DISTINCT pd.ProcCat) as ProcedureCategories
    FROM procedurelog pl
    JOIN procedurecode pd ON pl.CodeNum = pd.CodeNum
    WHERE pl.ProcStatus = 1  -- Treatment Planned
    AND pl.ProcDate >= '2025-01-01'
    AND pl.ProcDate < '2026-01-01'
    GROUP BY pl.PatNum
)
SELECT 
    jp.PatNum,
    jp.LName,
    jp.FName,
    jp.Preferred,
    jp.LastJanuaryApt,
    
    -- Future Status
    CASE 
        WHEN fa.AptStatus = 1 THEN 'Scheduled'
        WHEN fa.AptStatus = 6 THEN 'Unscheduled'
        WHEN pt.PlannedProcCount > 0 THEN 'Needs Scheduling'
        ELSE 'Needs Treatment Plan'
    END as FutureStatus,
    
    -- Treatment Plan Details
    COALESCE(pt.PlannedProcCount, 0) as PlannedProcedures,
    COALESCE(pt.PlannedProcCodes, '') as PlannedProcCodes,
    COALESCE(pt.ProcedureDescriptions, '') as ProcedureDescriptions,
    COALESCE(pt.ProcedureCategories, '') as ProcedureCategories,
    
    -- Contact Information
    jp.HmPhone,
    jp.WkPhone,
    jp.WirelessPhone,
    jp.Email,
    
    -- Future Appointment Details
    fa.NextAptDateTime,
    
    -- Recall Status
    CASE WHEN EXISTS (
        SELECT 1 FROM recall r 
        WHERE r.PatNum = jp.PatNum 
        AND r.DateDue > '2025-01-01'
    ) THEN 'Has Active Recall' 
    ELSE 'No Active Recall' 
    END as RecallStatus

FROM JanuaryPatients jp
LEFT JOIN PlannedTreatments pt ON jp.PatNum = pt.PatNum
LEFT JOIN (
    SELECT 
        PatNum,
        MIN(AptDateTime) as NextAptDateTime,
        AptStatus
    FROM appointment
    WHERE AptDateTime >= '2025-01-01'
    AND AptDateTime < '2026-01-01'
    AND AptStatus IN (1, 6)
    GROUP BY PatNum, AptStatus
) fa ON jp.PatNum = fa.PatNum

WHERE 
    (fa.AptStatus IS NULL OR fa.AptStatus = 6)
    AND jp.PatStatus = 0

ORDER BY 
    CASE 
        WHEN pt.PlannedProcCount > 0 THEN 1
        ELSE 2
    END,
    COALESCE(pt.PlannedProcCount, 0) DESC,
    jp.LastJanuaryApt DESC; 