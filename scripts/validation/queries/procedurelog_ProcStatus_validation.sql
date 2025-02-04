-- =============================================
-- Procedure Status (ProcStatus) Analysis Script
-- Purpose: Validate and understand the meaning of different procedure status values
-- =============================================

-- 1. Overall Distribution
-- Shows the frequency of each ProcStatus value across all procedures
SELECT 
    pl.ProcStatus,
    COUNT(*) as Count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM procedurelog), 2) as Percentage
FROM procedurelog pl
GROUP BY pl.ProcStatus
ORDER BY pl.ProcStatus;

-- 2. Sample Procedures for Each Status
-- Gets one recent example of each status to examine their characteristics
SELECT 
    pl.ProcStatus,
    pc.ProcCode,
    pc.Descript as ProcedureDescription,
    pl.ProcFee,
    pl.DateTP,
    pl.ProcDate,
    pl.DateComplete,
    pl.AptNum,
    pl.ProvNum
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE pl.ProcStatus IN (1,2,3,4,5,6,7,8)
    AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY pl.ProcStatus
ORDER BY pl.ProcStatus;

-- 3. Detailed Status Analysis
-- Analyzes completion rates and appointment linkage for each status
WITH SampleProcs AS (
    SELECT 
        pl.ProcStatus,
        pc.ProcCode,
        pc.Descript as ProcedureDescription,
        pl.ProcFee,
        pl.DateTP as TreatmentPlanDate,
        pl.ProcDate as ScheduledDate,
        pl.DateComplete as CompletionDate,
        pl.AptNum,
        -- Flag if procedure was completed
        CASE 
            WHEN pl.DateComplete != '0001-01-01' THEN 'Yes'
            WHEN pl.DateComplete = '0001-01-01' THEN 'No'
        END as WasCompleted,
        -- Flag if procedure has appointment
        CASE 
            WHEN pl.AptNum > 0 THEN 'Yes'
            ELSE 'No'
        END as HasAppointment,
        a.AptStatus
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN appointment a ON pl.AptNum = a.AptNum
    WHERE pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
)
SELECT 
    ProcStatus,
    COUNT(*) as TotalCount,
    SUM(CASE WHEN WasCompleted = 'Yes' THEN 1 ELSE 0 END) as CompletedCount,
    SUM(CASE WHEN HasAppointment = 'Yes' THEN 1 ELSE 0 END) as WithAppointment,
    GROUP_CONCAT(DISTINCT AptStatus) as LinkedAptStatuses
FROM SampleProcs
GROUP BY ProcStatus
ORDER BY ProcStatus;

-- 4. Detailed Analysis of Planned vs Completed
-- Focuses on ProcStatus 1 (Planned) and 2 (Completed) to understand their relationship with appointments
SELECT 
    pl.ProcStatus,
    a.AptStatus,
    COUNT(*) as Count,
    MIN(pl.DateComplete) as EarliestComplete,
    MAX(pl.DateComplete) as LatestComplete
FROM procedurelog pl
LEFT JOIN appointment a ON pl.AptNum = a.AptNum
WHERE pl.ProcStatus IN (1,2)
    AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY pl.ProcStatus, a.AptStatus
ORDER BY pl.ProcStatus, a.AptStatus;

-- 1. Main Status Analysis
WITH StatusAnalysis AS (
    SELECT 
        pl.ProcStatus,
        pc.ProcCode,
        pc.Descript as ProcedureDescription,
        pl.ProcFee,
        pl.DateTP as TreatmentPlanDate,
        pl.ProcDate as ScheduledDate,
        pl.AptNum,
        a.AptStatus,
        pl.ProvNum
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN appointment a ON pl.AptNum = a.AptNum
    WHERE pl.ProcStatus IN (3,4,6)
        AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
)
SELECT 
    ProcStatus,
    COUNT(*) as TotalCount,
    COUNT(DISTINCT ProcCode) as UniqueProcedures,
    ROUND(AVG(ProcFee), 2) as AvgFee,
    SUM(CASE WHEN ProcFee = 0 THEN 1 ELSE 0 END) as ZeroFeeCount,
    COUNT(CASE WHEN TreatmentPlanDate != '0001-01-01' THEN 1 END) as HasTPDate,
    COUNT(CASE WHEN AptNum > 0 THEN 1 END) as HasAppointment,
    GROUP_CONCAT(DISTINCT AptStatus) as LinkedAptStatuses
FROM StatusAnalysis
GROUP BY ProcStatus;





-- 2. Common Procedures Analysis
SELECT 
    pl.ProcStatus,
    pc.ProcCode,
    pc.Descript as ProcedureDescription,
    COUNT(*) as Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY pl.ProcStatus), 2) as PercentageWithinStatus,
    MIN(pl.ProcDate) as EarliestDate,
    MAX(pl.ProcDate) as LatestDate
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE pl.ProcStatus IN (3,4,6)
    AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY pl.ProcStatus, pc.ProcCode, pc.Descript
HAVING Count > 10
ORDER BY pl.ProcStatus, Count DESC;


-- 1. Distribution of ProcStatus for missed/cancelled appointments
SELECT 
    pl.ProcStatus,
    pc.ProcCode,
    pc.Descript as ProcedureDescription,
    COUNT(*) as Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY pc.CodeNum), 2) as PercentageWithinCode
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE pc.CodeNum IN (626, 764, 627, 765)  -- Missed and Cancelled appointment codes
    AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY pl.ProcStatus, pc.ProcCode, pc.Descript
ORDER BY pc.ProcCode, pl.ProcStatus;

-- 2. Detailed look at individual missed/cancelled appointments
SELECT 
    pc.ProcCode,
    pc.Descript,
    pl.ProcStatus,
    pl.ProcFee,
    pl.DateTP,
    pl.ProcDate,
    pl.AptNum,
    a.AptStatus
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
LEFT JOIN appointment a ON pl.AptNum = a.AptNum
WHERE pc.CodeNum IN (626, 764, 627, 765)
    AND pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
LIMIT 100;