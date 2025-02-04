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

-- 3a. Fee Schedule Hierarchy Analysis
SELECT 
    proc.ProcNum,
    proc.CodeNum,
    pat.FeeSched as Patient_FeeSched,
    prov.FeeSched as Provider_FeeSched,
    COALESCE(pat_fs.Description, 'NULL') as Patient_FeeSchedDesc,
    COALESCE(prov_fs.Description, 'NULL') as Provider_FeeSchedDesc,
    proc.ProcFee as ActualFee,
    pat_fee.Amount as PatientFeeScheduleAmount,
    prov_fee.Amount as ProviderFeeScheduleAmount,
    CASE 
        WHEN pat_fee.Amount IS NOT NULL THEN 'Patient'
        WHEN prov_fee.Amount IS NOT NULL THEN 'Provider'
        ELSE 'Missing'
    END as FeeSource
FROM procedurelog proc
JOIN patient pat ON proc.PatNum = pat.PatNum
JOIN provider prov ON proc.ProvNum = prov.ProvNum
-- Patient's fee schedule path
LEFT JOIN feesched pat_fs ON pat.FeeSched = pat_fs.FeeSchedNum
LEFT JOIN fee pat_fee ON proc.CodeNum = pat_fee.CodeNum 
    AND pat_fee.FeeSched = pat.FeeSched
    AND (pat_fee.ClinicNum = proc.ClinicNum OR pat_fee.ClinicNum = 0)
-- Provider's fee schedule path
LEFT JOIN feesched prov_fs ON prov.FeeSched = prov_fs.FeeSchedNum
LEFT JOIN fee prov_fee ON proc.CodeNum = prov_fee.CodeNum 
    AND prov_fee.FeeSched = prov.FeeSched
    AND (prov_fee.ClinicNum = proc.ClinicNum OR prov_fee.ClinicNum = 0)
WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6)
    AND pat_fs.IsHidden = 0
LIMIT 1000;

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

-- 3d. Fee Schedule Coverage Analysis
WITH ProcedureCounts AS (
    SELECT 
        proc.ProcNum,
        CASE WHEN pat_fee.FeeNum IS NOT NULL THEN 1 ELSE 0 END as Has_Patient_Fee,
        CASE WHEN prov_fee.FeeNum IS NOT NULL THEN 1 ELSE 0 END as Has_Provider_Fee
    FROM procedurelog proc
    JOIN patient pat ON proc.PatNum = pat.PatNum
    JOIN provider prov ON proc.ProvNum = prov.ProvNum
    LEFT JOIN fee pat_fee ON proc.CodeNum = pat_fee.CodeNum 
        AND pat_fee.FeeSched = pat.FeeSched
        AND (pat_fee.ClinicNum = proc.ClinicNum OR pat_fee.ClinicNum = 0)
    LEFT JOIN fee prov_fee ON proc.CodeNum = prov_fee.CodeNum 
        AND prov_fee.FeeSched = prov.FeeSched
        AND (prov_fee.ClinicNum = proc.ClinicNum OR prov_fee.ClinicNum = 0)
    WHERE proc.ProcDate >= '2023-01-01'
        AND proc.ProcDate < '2024-01-01'
        AND proc.ProcStatus IN (1, 2, 5, 6)
)
SELECT 
    CASE 
        WHEN Has_Patient_Fee = 1 AND Has_Provider_Fee = 1 THEN 'Both Fee Schedules'
        WHEN Has_Patient_Fee = 1 THEN 'Patient Fee Schedule Only'
        WHEN Has_Provider_Fee = 1 THEN 'Provider Fee Schedule Only'
        ELSE 'No Fee Schedule'
    END as FeeScheduleCoverage,
    COUNT(*) as ProcedureCount,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as Percentage
FROM ProcedureCounts
GROUP BY 
    CASE 
        WHEN Has_Patient_Fee = 1 AND Has_Provider_Fee = 1 THEN 'Both Fee Schedules'
        WHEN Has_Patient_Fee = 1 THEN 'Patient Fee Schedule Only'
        WHEN Has_Provider_Fee = 1 THEN 'Provider Fee Schedule Only'
        ELSE 'No Fee Schedule'
    END
ORDER BY ProcedureCount DESC;

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