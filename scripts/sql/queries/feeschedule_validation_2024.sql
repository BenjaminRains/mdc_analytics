/*
Fee Schedule Validation Queries - 2024 Analysis
Purpose: Compare current fee schedule implementation with 2023 baseline
Tables: procedurelog, fee, feesched, insplan, carrier, claim, claimproc
Focus: Identify changes in patterns and potential issues
*/

-- 1. Basic Fee Schedule Volume Analysis (2024)
-- Purpose: Compare current volumes with 2023 baseline
SELECT 
    f.FeeSched,
    fs.Description,
    COUNT(*) as ProcedureCount,
    COUNT(DISTINCT pl.PatNum) as PatientCount,
    ROUND(AVG(pl.ProcFee), 2) as AvgProcFee,
    MIN(pl.ProcDate) as FirstProcDate,
    MAX(pl.ProcDate) as LastProcDate,
    '2024' as DataYear
FROM procedurelog pl
JOIN fee f ON pl.CodeNum = f.CodeNum 
JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
WHERE pl.ProcStatus = 2  -- Completed procedures
    AND pl.ProcDate >= '2024-01-01'
    AND pl.ProcDate < '2025-01-01'
    AND f.FeeSched IN (55, 54, 8278, 8274, 1642, 8286, 8291)
GROUP BY f.FeeSched, fs.Description
ORDER BY ProcedureCount DESC;

-- 2. Year-over-Year Comparison
-- Purpose: Identify significant changes in fee schedule usage
SELECT 
    f.FeeSched,
    fs.Description,
    YEAR(pl.ProcDate) as Year,
    COUNT(*) as ProcedureCount,
    COUNT(DISTINCT pl.PatNum) as PatientCount,
    ROUND(AVG(pl.ProcFee), 2) as AvgProcFee,
    ROUND(SUM(pl.ProcFee), 2) as TotalFees
FROM procedurelog pl
JOIN fee f ON pl.CodeNum = f.CodeNum 
JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
WHERE pl.ProcStatus = 2
    AND pl.ProcDate >= '2023-01-01'
    AND pl.ProcDate < '2025-01-01'
    AND f.FeeSched IN (55, 54, 8278, 8274, 1642, 8286, 8291)
GROUP BY f.FeeSched, fs.Description, YEAR(pl.ProcDate)
ORDER BY Year DESC, ProcedureCount DESC;

-- 3. Current Insurance Plan Configuration
-- Purpose: Check for changes in insurance plan setups
SELECT 
    i.PlanNum,
    i.GroupName,
    i.GroupNum,
    i.FeeSched as PrimaryFeeSched,
    i.CopayFeeSched,
    i.AllowedFeeSched,
    i.CarrierNum,
    c.CarrierName,
    COUNT(DISTINCT pl.ProcNum) as Procedures2024
FROM insplan i
JOIN carrier c ON i.CarrierNum = c.CarrierNum
LEFT JOIN claimproc cp ON i.PlanNum = cp.PlanNum
LEFT JOIN procedurelog pl ON cp.ProcNum = pl.ProcNum 
    AND YEAR(pl.ProcDate) = 2024
WHERE i.FeeSched IN (55, 54, 8278, 8274, 1642, 8286, 8291)
GROUP BY i.PlanNum, i.GroupName, i.GroupNum, i.FeeSched, i.CarrierNum, c.CarrierName
ORDER BY Procedures2024 DESC;

-- 4. Claims Analysis 2024
-- Purpose: Monitor current claim patterns
SELECT 
    f.FeeSched,
    fs.Description,
    COUNT(DISTINCT c.ClaimNum) as ClaimCount,
    COUNT(DISTINCT cp.ClaimProcNum) as ProcedureCount,
    ROUND(AVG(cp.FeeBilled), 2) as AvgFeeBilled,
    ROUND(AVG(cp.InsPayEst), 2) as AvgInsuranceEst,
    ROUND(AVG(cp.InsPayAmt), 2) as AvgInsurancePaid,
    ROUND(AVG(cp.WriteOff), 2) as AvgWriteOff
FROM claim c
JOIN insplan i ON c.PlanNum = i.PlanNum
JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum
JOIN fee f ON cp.ProcNum = f.CodeNum
JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
WHERE c.ClaimStatus = 'S'
    AND c.DateService >= '2024-01-01'
    AND c.DateService < '2025-01-01'
    AND f.FeeSched IN (55, 54, 8278, 8274, 1642, 8286, 8291)
GROUP BY f.FeeSched, fs.Description
ORDER BY ProcedureCount DESC;

-- 5. Fee Schedule Override Tracking
-- Purpose: Monitor manual overrides and special cases
SELECT 
    i.PlanNum,
    i.GroupName,
    i.FeeSched as PlanFeeSched,
    i.CopayFeeSched,
    i.AllowedFeeSched,
    i.ManualFeeSchedNum,
    c.CarrierName,
    COUNT(DISTINCT cp.ClaimProcNum) as ProcedureCount,
    ROUND(AVG(pl.ProcFee), 2) as AvgProcFee
FROM insplan i
JOIN carrier c ON i.CarrierNum = c.CarrierNum
LEFT JOIN claimproc cp ON i.PlanNum = cp.PlanNum
LEFT JOIN procedurelog pl ON cp.ProcNum = pl.ProcNum
WHERE i.FeeSched = 55
    AND pl.ProcDate >= '2024-01-01'
    AND pl.ProcDate < '2025-01-01'
GROUP BY i.PlanNum, i.GroupName, i.FeeSched, c.CarrierName
ORDER BY ProcedureCount DESC;

-- 6. Monthly Trend Analysis 2024
-- Purpose: Track fee schedule usage patterns through the year
SELECT 
    f.FeeSched,
    fs.Description,
    DATE_FORMAT(pl.ProcDate, '%Y-%m') as Month,
    COUNT(*) as ProcedureCount,
    COUNT(DISTINCT pl.PatNum) as PatientCount,
    ROUND(AVG(pl.ProcFee), 2) as AvgProcFee
FROM procedurelog pl
JOIN fee f ON pl.CodeNum = f.CodeNum 
JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
WHERE pl.ProcStatus = 2
    AND pl.ProcDate >= '2024-01-01'
    AND pl.ProcDate < '2025-01-01'
    AND f.FeeSched IN (55, 54, 8278, 8274, 1642, 8286, 8291)
GROUP BY f.FeeSched, fs.Description, Month
ORDER BY Month, ProcedureCount DESC; 