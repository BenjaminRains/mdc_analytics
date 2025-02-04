-- Validate Missed/Cancelled Appointment Recording Methods
-- =================================================

-- 1. Basic distribution of missed/cancelled procedure codes
SELECT 
    pc.CodeNum,
    pc.ProcCode,
    pc.Descript,
    pl.ProcStatus,
    COUNT(*) as Count,
    COUNT(DISTINCT pl.PatNum) as UniquePatients,
    MIN(pl.ProcDate) as EarliestDate,
    MAX(pl.ProcDate) as LatestDate,
    COUNT(DISTINCT CASE WHEN a.AptStatus = 5 THEN pl.ProcNum END) as BrokenAptCount
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
LEFT JOIN appointment a ON pl.AptNum = a.AptNum
WHERE pc.CodeNum IN (
    626,  -- D9986 (Missed)
    764,  -- 00041 (Missed - Legacy)
    627,  -- D9987 (Cancelled)
    765   -- 00042 (Cancelled - Legacy)
)
AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
GROUP BY pc.CodeNum, pc.ProcCode, pc.Descript, pl.ProcStatus
ORDER BY pc.CodeNum, pl.ProcStatus;

-- 2. Check overlap between AptStatus = 5 and procedure codes
SELECT 
    CASE 
        WHEN a.AptStatus = 5 AND pl.CodeNum IN (626, 764, 627, 765) THEN 'Both'
        WHEN a.AptStatus = 5 THEN 'Only AptStatus'
        WHEN pl.CodeNum IN (626, 764, 627, 765) THEN 'Only ProcCode'
        ELSE 'Neither'
    END as RecordingMethod,
    COUNT(*) as Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as Percentage,
    COUNT(DISTINCT a.PatNum) as UniquePatients
FROM appointment a
LEFT JOIN procedurelog pl ON a.AptNum = pl.AptNum
WHERE a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
    AND (a.AptStatus = 5 OR pl.CodeNum IN (626, 764, 627, 765))
GROUP BY 
    CASE 
        WHEN a.AptStatus = 5 AND pl.CodeNum IN (626, 764, 627, 765) THEN 'Both'
        WHEN a.AptStatus = 5 THEN 'Only AptStatus'
        WHEN pl.CodeNum IN (626, 764, 627, 765) THEN 'Only ProcCode'
        ELSE 'Neither'
    END
ORDER BY Count DESC;

-- 3. Analyze ProcStatus distribution for missed/cancelled appointments
SELECT 
    pl.ProcStatus,
    COUNT(*) as Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as Percentage,
    COUNT(DISTINCT pl.PatNum) as UniquePatients,
    STRING_AGG(DISTINCT pc.ProcCode, ', ') as ProcCodes
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE pl.CodeNum IN (626, 764, 627, 765)
    AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
GROUP BY pl.ProcStatus
ORDER BY Count DESC;

-- 4. Analyze temporal patterns
SELECT 
    YEAR(pl.ProcDate) as Year,
    MONTH(pl.ProcDate) as Month,
    COUNT(CASE WHEN pl.CodeNum IN (626, 764) THEN 1 END) as MissedCount,
    COUNT(CASE WHEN pl.CodeNum IN (627, 765) THEN 1 END) as CancelledCount,
    COUNT(DISTINCT CASE WHEN a.AptStatus = 5 THEN a.AptNum END) as BrokenAptCount
FROM procedurelog pl
LEFT JOIN appointment a ON pl.AptNum = a.AptNum
WHERE (pl.CodeNum IN (626, 764, 627, 765) OR a.AptStatus = 5)
    AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
GROUP BY YEAR(pl.ProcDate), MONTH(pl.ProcDate)
ORDER BY Year, Month;

-- 5. Check for same-day multiple recordings
SELECT 
    pl.PatNum,
    pl.ProcDate,
    COUNT(DISTINCT pl.ProcNum) as ProcCount,
    COUNT(DISTINCT CASE WHEN pl.CodeNum IN (626, 764) THEN pl.ProcNum END) as MissedCount,
    COUNT(DISTINCT CASE WHEN pl.CodeNum IN (627, 765) THEN pl.ProcNum END) as CancelledCount,
    COUNT(DISTINCT CASE WHEN a.AptStatus = 5 THEN a.AptNum END) as BrokenAptCount
FROM procedurelog pl
LEFT JOIN appointment a ON pl.AptNum = a.AptNum
WHERE (pl.CodeNum IN (626, 764, 627, 765) OR a.AptStatus = 5)
    AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
GROUP BY pl.PatNum, pl.ProcDate
HAVING ProcCount > 1
ORDER BY ProcCount DESC; 