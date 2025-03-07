-- Treatment Journey ML Validation Queries
-- Run these individually to validate data quality and assumptions

-- 1. Basic Treatment Planning Validation
SELECT 
    proc.ProcNum,
    proc.ProcDate,
    proc.DateTP as PlanDate,
    CASE 
        WHEN proc.DateTP = '0001-01-01' THEN NULL
        ELSE DATEDIFF(proc.ProcDate, proc.DateTP)
    END as DaysFromPlanToProc,
    CASE 
        WHEN proc.DateTP = '0001-01-01' THEN 0
        ELSE 1
    END as WasPlanned
FROM procedurelog proc
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6)
LIMIT 1000;

-- 2a. Patient Demographics Basic Validation
SELECT 
    proc.ProcNum,
    proc.PatNum,
    pat.Birthdate,
    proc.ProcDate,
    CASE 
        WHEN pat.Birthdate = '0001-01-01' THEN NULL
        WHEN pat.Birthdate > proc.ProcDate THEN NULL
        ELSE TIMESTAMPDIFF(YEAR, pat.Birthdate, proc.ProcDate) 
    END as PatientAge,
    pat.Gender,
    CASE WHEN pat.HasIns != '' THEN 1 ELSE 0 END as HasInsurance
FROM procedurelog proc
JOIN patient pat ON proc.PatNum = pat.PatNum
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6)
LIMIT 1000;

-- 2b. Gender Distribution Summary
SELECT 
    pat.Gender,
    COUNT(*) as ProcedureCount,
    COUNT(DISTINCT proc.PatNum) as UniquePatients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as PercentageOfProcedures
FROM procedurelog proc
JOIN patient pat ON proc.PatNum = pat.PatNum
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6)
GROUP BY pat.Gender
ORDER BY ProcedureCount DESC;

-- 3b. Fee Schedule Usage Summary
SELECT 
    'Total Procedures' as Metric,
    COUNT(*) as Count
FROM procedurelog proc
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6)

UNION ALL

SELECT 
    'Using Patient FeeSchedule',
    COUNT(*)
FROM procedurelog proc
JOIN patient pat ON proc.PatNum = pat.PatNum
JOIN fee f ON proc.CodeNum = f.CodeNum 
    AND f.FeeSched = pat.FeeSched
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6)

UNION ALL

SELECT 
    'Using Provider FeeSchedule',
    COUNT(*)
FROM procedurelog proc
JOIN provider prov ON proc.ProvNum = prov.ProvNum
JOIN fee f ON proc.CodeNum = f.CodeNum 
    AND f.FeeSched = prov.FeeSched
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6);

-- 3c. Fee Schedule Distribution Analysis (Updated)
WITH FeeSchedStats AS (
    SELECT 
        fs.FeeSchedNum,
        fs.Description,
        fs.FeeSchedType,
        fs.IsHidden,
        COUNT(DISTINCT pat.PatNum) as PatientCount,
        COUNT(DISTINCT prov.ProvNum) as ProviderCount,
        COUNT(DISTINCT CASE 
            WHEN proc.ProcDate >= '2023-01-01' 
            AND proc.ProcDate < '2024-01-01'
            AND proc.ProcStatus IN (1, 2, 5, 6)
            THEN proc.ProcNum 
        END) as ProcedureCount,
        COUNT(DISTINCT f.CodeNum) as UniqueCodesCount
    FROM feesched fs
    LEFT JOIN patient pat ON fs.FeeSchedNum = pat.FeeSched
    LEFT JOIN provider prov ON fs.FeeSchedNum = prov.FeeSched
    LEFT JOIN procedurelog proc ON (proc.PatNum = pat.PatNum OR proc.ProvNum = prov.ProvNum)
    LEFT JOIN fee f ON fs.FeeSchedNum = f.FeeSched
    WHERE fs.IsHidden = 0
    GROUP BY fs.FeeSchedNum, fs.Description, fs.FeeSchedType, fs.IsHidden
)
SELECT 
    FeeSchedNum,
    Description,
    CASE FeeSchedType
        WHEN 1 THEN 'Standard'
        WHEN 2 THEN 'Insurance'
        WHEN 3 THEN 'Sliding Scale'
        ELSE 'Other'
    END as FeeSchedType,
    PatientCount,
    ProviderCount,
    ProcedureCount,
    UniqueCodesCount
FROM FeeSchedStats
WHERE ProcedureCount > 0 OR PatientCount > 0 OR ProviderCount > 0
ORDER BY ProcedureCount DESC, PatientCount DESC;

-- 3c. Fee Schedule Distribution Analysis (Optimized)
WITH ActiveFeeScheds AS (
    -- First get only active fee schedules to limit joins
    SELECT 
        fs.FeeSchedNum,
        fs.Description,
        fs.FeeSchedType,
        fs.IsHidden
    FROM feesched fs
    WHERE fs.IsHidden = 0
),
PatientCounts AS (
    -- Get patient counts separately
    SELECT 
        FeeSched,
        COUNT(DISTINCT PatNum) as PatientCount
    FROM patient 
    WHERE FeeSched IN (SELECT FeeSchedNum FROM ActiveFeeScheds)
    GROUP BY FeeSched
),
ProviderCounts AS (
    -- Get provider counts separately
    SELECT 
        FeeSched,
        COUNT(DISTINCT ProvNum) as ProviderCount
    FROM provider 
    WHERE FeeSched IN (SELECT FeeSchedNum FROM ActiveFeeScheds)
    GROUP BY FeeSched
),
ProcedureCounts AS (
    -- Get procedure counts separately with date filtering upfront
    SELECT 
        pat.FeeSched,
        COUNT(DISTINCT proc.ProcNum) as ProcedureCount
    FROM procedurelog proc
    JOIN patient pat ON proc.PatNum = pat.PatNum
    WHERE proc.ProcDate >= '2023-01-01' 
        AND proc.ProcDate < '2024-01-01'
        AND proc.ProcStatus IN (1, 2, 5, 6)
        AND pat.FeeSched IN (SELECT FeeSchedNum FROM ActiveFeeScheds)
    GROUP BY pat.FeeSched
),
CodeCounts AS (
    -- Get unique code counts separately
    SELECT 
        FeeSched,
        COUNT(DISTINCT CodeNum) as UniqueCodesCount
    FROM fee
    WHERE FeeSched IN (SELECT FeeSchedNum FROM ActiveFeeScheds)
    GROUP BY FeeSched
)
SELECT 
    fs.FeeSchedNum,
    fs.Description,
    CASE fs.FeeSchedType
        WHEN 1 THEN 'Standard'
        WHEN 2 THEN 'Insurance'
        WHEN 3 THEN 'Sliding Scale'
        ELSE 'Other'
    END as FeeSchedType,
    COALESCE(pc.PatientCount, 0) as PatientCount,
    COALESCE(pr.ProviderCount, 0) as ProviderCount,
    COALESCE(proc.ProcedureCount, 0) as ProcedureCount,
    COALESCE(cc.UniqueCodesCount, 0) as UniqueCodesCount
FROM ActiveFeeScheds fs
LEFT JOIN PatientCounts pc ON fs.FeeSchedNum = pc.FeeSched
LEFT JOIN ProviderCounts pr ON fs.FeeSchedNum = pr.FeeSched
LEFT JOIN ProcedureCounts proc ON fs.FeeSchedNum = proc.FeeSched
LEFT JOIN CodeCounts cc ON fs.FeeSchedNum = cc.FeeSched
WHERE COALESCE(proc.ProcedureCount, 0) > 0 
    OR COALESCE(pc.PatientCount, 0) > 0 
    OR COALESCE(pr.ProviderCount, 0) > 0
ORDER BY ProcedureCount DESC, PatientCount DESC;

-- 4. Insurance Claims Validation
SELECT 
    proc.ProcNum,
    cp.InsPayEst as EstimatedPayment,
    cp.InsPayAmt as ActualPayment,
    CASE 
        WHEN cp.InsPayEst > 0 THEN 
            (cp.InsPayAmt / cp.InsPayEst) * 100
        ELSE NULL 
    END as InsurancePaymentAccuracy,
    c.ClaimStatus,
    c.DateSent,
    c.DateReceived,
    COUNT(*) OVER (PARTITION BY c.ClaimStatus) as ClaimStatusCount
FROM procedurelog proc
LEFT JOIN claimproc cp ON proc.ProcNum = cp.ProcNum
LEFT JOIN claim c ON cp.ClaimNum = c.ClaimNum
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6)
LIMIT 1000;

-- 5. Payment Pattern Validation
SELECT 
    proc.ProcNum,
    proc.ProcFee,
    COALESCE((SELECT SUM(ps.SplitAmt) FROM paysplit ps WHERE ps.ProcNum = proc.ProcNum), 0) as TotalPayments,
    COALESCE(cp.InsPayAmt, 0) as InsurancePayment,
    COALESCE((SELECT SUM(adj.AdjAmt) FROM adjustment adj WHERE adj.ProcNum = proc.ProcNum), 0) as Adjustments,
    CASE 
        WHEN proc.ProcFee <= 0 THEN NULL
        WHEN proc.ProcFee <= COALESCE(
            (SELECT SUM(ps.SplitAmt) FROM paysplit ps WHERE ps.ProcNum = proc.ProcNum), 0
        ) + COALESCE(cp.InsPayAmt, 0) + COALESCE(
            (SELECT SUM(adj.AdjAmt) FROM adjustment adj WHERE adj.ProcNum = proc.ProcNum), 0
        ) THEN 1 
        ELSE 0 
    END as target_fully_paid
FROM procedurelog proc
LEFT JOIN claimproc cp ON proc.ProcNum = cp.ProcNum
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6)
    AND proc.ProcFee > 0
LIMIT 1000;

-- 6. Data Quality Checks
SELECT 
    COUNT(*) as total_procedures,
    COUNT(DISTINCT proc.PatNum) as unique_patients,
    SUM(CASE WHEN proc.DateTP = '0001-01-01' THEN 1 ELSE 0 END) as unplanned_procedures,
    SUM(CASE WHEN pat.Birthdate = '0001-01-01' THEN 1 ELSE 0 END) as missing_birthdates,
    SUM(CASE WHEN pat.Gender IS NULL THEN 1 ELSE 0 END) as missing_gender,
    AVG(CASE WHEN proc.ProcFee > 0 THEN proc.ProcFee ELSE NULL END) as avg_procedure_fee
FROM procedurelog proc
JOIN patient pat ON proc.PatNum = pat.PatNum
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6);

-- Analyze procedure fees and their relationship to fee schedules
SELECT 
    f.FeeSched,
    fs.Description,
    COUNT(DISTINCT pl.ProcNum) as ProcedureCount,
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
GROUP BY f.FeeSched, fs.Description
ORDER BY ProcedureCount DESC; 