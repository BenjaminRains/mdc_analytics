/*
Fee Schedule Validation Queries
Purpose: Comprehensive analysis of fee schedule implementation and usage
Tables: procedurelog, fee, feesched, insplan, carrier, claim, claimproc
Key Areas:
- Fee schedule volume and usage
- Insurance plan configurations
- Claims and payment patterns
- Fee schedule overrides
*/

-- 1. Basic Fee Schedule Volume Analysis
-- Purpose: Identify active fee schedules and their usage patterns
SELECT 
    f.FeeSched,
    fs.Description,
    COUNT(*) as ProcedureCount,
    COUNT(DISTINCT pl.PatNum) as PatientCount,
    ROUND(AVG(pl.ProcFee), 2) as AvgProcFee,
    MIN(pl.ProcDate) as FirstProcDate,
    MAX(pl.ProcDate) as LastProcDate
FROM procedurelog pl
JOIN fee f ON pl.CodeNum = f.CodeNum 
JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
WHERE pl.ProcStatus = 2  -- Completed procedures
    AND pl.ProcDate >= '2023-01-01'
    AND pl.ProcDate < '2024-01-01'
    AND f.FeeSched IN (55, 54, 8278, 8274, 1642, 8286, 8291)
GROUP BY f.FeeSched, fs.Description
ORDER BY ProcedureCount DESC;

-- 2. Detailed Fee Schedule Metrics
-- Purpose: Analyze fee patterns and potential data quality issues
SELECT 
    f.FeeSched,
    fs.Description,
    COUNT(*) as ProcedureCount,
    COUNT(DISTINCT pl.PatNum) as PatientCount,
    ROUND(AVG(pl.ProcFee), 2) as AvgProcFee,
    ROUND(SUM(pl.ProcFee), 2) as TotalFees,
    COUNT(DISTINCT pl.CodeNum) as UniqueProcCodes,
    COUNT(DISTINCT MONTH(pl.ProcDate)) as MonthsActive
FROM procedurelog pl
JOIN fee f ON pl.CodeNum = f.CodeNum 
JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
WHERE pl.ProcStatus = 2
    AND pl.ProcDate >= '2023-01-01'
    AND pl.ProcDate < '2024-01-01'
    AND f.FeeSched IN (55, 54, 8278, 8274, 1642, 8286, 8291)
GROUP BY f.FeeSched, fs.Description
ORDER BY ProcedureCount DESC;

-- 3. Insurance Plan Fee Schedule Configuration
-- Purpose: Map insurance plans to their assigned fee schedules
SELECT 
    i.PlanNum,
    i.GroupName,
    i.GroupNum,
    i.FeeSched as PrimaryFeeSched,
    i.CopayFeeSched,
    i.AllowedFeeSched,
    i.CarrierNum,
    c.CarrierName
FROM insplan i
JOIN carrier c ON i.CarrierNum = c.CarrierNum
WHERE i.FeeSched IN (55, 54, 8278, 8274, 1642, 8286, 8291)
ORDER BY i.FeeSched;

-- 4. Claims and Payment Analysis
-- Purpose: Analyze how fee schedules affect claims and payments
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
    AND c.DateService >= '2023-01-01'
    AND c.DateService < '2024-01-01'
    AND f.FeeSched IN (55, 54, 8278, 8274, 1642, 8286, 8291)
GROUP BY f.FeeSched, fs.Description
ORDER BY ProcedureCount DESC;

-- 5. Carrier Fee Schedule Distribution
-- Purpose: Analyze how carriers use different fee schedules
SELECT 
    c.CarrierName,
    i.FeeSched,
    COUNT(DISTINCT i.PlanNum) as PlanCount,
    GROUP_CONCAT(DISTINCT i.GroupName) as GroupNames
FROM insplan i
JOIN carrier c ON i.CarrierNum = c.CarrierNum
WHERE i.FeeSched > 0
GROUP BY c.CarrierName, i.FeeSched
ORDER BY PlanCount DESC;

-- 6. Fee Schedule Override Analysis
-- Purpose: Identify where fee schedules might be getting overridden
SELECT 
    i.PlanNum,
    i.GroupName,
    i.FeeSched as PlanFeeSched,
    i.CopayFeeSched,
    i.AllowedFeeSched,
    i.ManualFeeSchedNum,
    c.CarrierName,
    COUNT(DISTINCT cp.ClaimProcNum) as ProcedureCount
FROM insplan i
JOIN carrier c ON i.CarrierNum = c.CarrierNum
LEFT JOIN claimproc cp ON i.PlanNum = cp.PlanNum
WHERE i.FeeSched = 55  -- Focus on Standard fee schedule
GROUP BY i.PlanNum, i.GroupName, i.FeeSched, c.CarrierName
ORDER BY ProcedureCount DESC;

-- 7. Fee Schedule Mismatch Detection
-- Purpose: Find cases where actual fee schedule differs from plan assignment
SELECT 
    i.PlanNum,
    i.GroupName,
    i.FeeSched as PlanFeeSched,
    i.CopayFeeSched,
    i.AllowedFeeSched,
    i.ManualFeeSchedNum,
    f.FeeSched as ActualFeeSched,
    COUNT(*) as ProcCount
FROM insplan i
JOIN claimproc cp ON i.PlanNum = cp.PlanNum
JOIN procedurelog pl ON cp.ProcNum = pl.ProcNum
JOIN fee f ON pl.CodeNum = f.CodeNum
WHERE i.FeeSched = 55
    AND f.FeeSched != 55
GROUP BY 
    i.PlanNum,
    i.GroupName,
    i.FeeSched,
    f.FeeSched;