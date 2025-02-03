WITH JanuaryPatients AS (
    -- Get all patients seen in January 2025
    SELECT DISTINCT 
        p.PatNum,
        p.LName,
        p.FName,
        MAX(a.AptDateTime) as LastJanuaryApt
    FROM patient p
    JOIN appointment a ON p.PatNum = a.PatNum
    WHERE a.AptDateTime >= '2025-01-01' 
    AND a.AptDateTime < '2025-02-01'
    AND a.AptStatus = 2  -- Completed
    GROUP BY p.PatNum, p.LName, p.FName
)
SELECT 
    jp.PatNum,
    jp.LName,
    jp.FName,
    jp.LastJanuaryApt,
    
    -- Future Appointment Analysis
    CASE 
        WHEN fa.AptStatus = 1 THEN 'Scheduled'
        WHEN fa.AptStatus = 6 THEN 'Unscheduled'
        WHEN tp.HasPlannedProcs = 1 THEN 'Has Treatment Plan Only'
        ELSE 'No Future Plans'
    END as FutureStatus,
    
    -- Treatment Plan Details
    tp.PlannedProcCount,
    fa.NextAptDateTime,
    fa.AptStatus as FutureAptStatus

FROM JanuaryPatients jp
-- Check Treatment Plans
LEFT JOIN (
    SELECT 
        PatNum,
        COUNT(*) as PlannedProcCount,
        1 as HasPlannedProcs
    FROM procedurelog 
    WHERE ProcStatus = 1
    AND ProcDate > '2025-02-01'
    GROUP BY PatNum
) tp ON jp.PatNum = tp.PatNum

-- Check Future Appointments
LEFT JOIN (
    SELECT 
        PatNum,
        MIN(AptDateTime) as NextAptDateTime,
        AptStatus
    FROM appointment
    WHERE AptDateTime >= '2025-02-01'
    AND AptDateTime < '2026-01-01'  -- Looking one year ahead
    AND AptStatus IN (1, 6)  -- Include both Scheduled and Unscheduled
    GROUP BY PatNum, AptStatus
) fa ON jp.PatNum = fa.PatNum

ORDER BY 
    CASE 
        WHEN fa.AptStatus IS NULL AND tp.HasPlannedProcs = 1 THEN 1
        WHEN fa.AptStatus IS NULL THEN 2
        ELSE 3
    END,
    jp.LastJanuaryApt DESC; 