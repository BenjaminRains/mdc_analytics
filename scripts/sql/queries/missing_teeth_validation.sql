-- 1. Check InitialType values in toothinitial
SELECT 
    InitialType,
    COUNT(*) as Count,
    COUNT(DISTINCT PatNum) as UniquePatients,
    GROUP_CONCAT(DISTINCT ToothNum ORDER BY ToothNum) as TeethNumbers
FROM toothinitial
GROUP BY InitialType
ORDER BY InitialType;

-- 2. Check for potential data inconsistencies
SELECT 
    ti.PatNum,
    p.LName,
    p.FName,
    ti.ToothNum,
    ti.InitialType,
    -- Check for multiple status entries for same tooth
    COUNT(*) as StatusCount,
    GROUP_CONCAT(DISTINCT ti.InitialType) as StatusTypes
FROM toothinitial ti
JOIN patient p ON ti.PatNum = p.PatNum
GROUP BY ti.PatNum, ti.ToothNum
HAVING COUNT(*) > 1
ORDER BY ti.PatNum, ti.ToothNum;

-- 3. Validate tooth numbers
SELECT 
    ToothNum,
    COUNT(*) as Occurrences,
    COUNT(DISTINCT PatNum) as UniquePatients,
    GROUP_CONCAT(DISTINCT InitialType) as StatusTypes
FROM toothinitial
WHERE ToothNum NOT BETWEEN 1 AND 32  -- Check for invalid tooth numbers
GROUP BY ToothNum
ORDER BY ToothNum;

-- 4. Cross-reference with procedures
SELECT 
    ti.PatNum,
    p.LName,
    p.FName,
    ti.ToothNum,
    ti.InitialType,
    GROUP_CONCAT(DISTINCT pl.ProcCode) as RelatedProcedures,
    GROUP_CONCAT(DISTINCT pl.ProcStatus) as ProcedureStatuses
FROM toothinitial ti
JOIN patient p ON ti.PatNum = p.PatNum
LEFT JOIN procedurelog pl ON 
    ti.PatNum = pl.PatNum 
    AND ti.ToothNum = pl.ToothNum
WHERE ti.InitialType = 0  -- Missing teeth
GROUP BY ti.PatNum, ti.ToothNum
HAVING RelatedProcedures IS NOT NULL
ORDER BY ti.PatNum, ti.ToothNum;

-- 5. Check for active patients with missing teeth status
SELECT 
    p.PatStatus,
    COUNT(DISTINCT p.PatNum) as TotalPatients,
    COUNT(DISTINCT CASE WHEN ti.InitialType = 0 THEN p.PatNum END) as PatientsWithMissingTeeth,
    COUNT(DISTINCT CASE WHEN ti.InitialType = 3 THEN p.PatNum END) as PatientsWithImpactedTeeth
FROM patient p
LEFT JOIN toothinitial ti ON p.PatNum = ti.PatNum
GROUP BY p.PatStatus
ORDER BY p.PatStatus;

-- 6. Verify implant recommendation logic
SELECT 
    ImplantRecommendation,
    COUNT(*) as PatientCount,
    MIN(MissingTeethCount) as MinTeeth,
    MAX(MissingTeethCount) as MaxTeeth,
    SUM(CASE WHEN HasMissingAnteriorTeeth = 'Yes' THEN 1 ELSE 0 END) as WithAnteriorMissing,
    SUM(CASE WHEN HasMissingFirstMolars = 'Yes' THEN 1 ELSE 0 END) as WithFirstMolarsMissing
FROM (
    -- Original missing teeth query here
    WITH missing_teeth AS (
        SELECT
            p.PatNum,
            COUNT(ti.ToothNum) AS MissingTeethCount,
            GROUP_CONCAT(ti.ToothNum ORDER BY ti.ToothNum) AS MissingTeeth
        FROM patient p
        INNER JOIN toothinitial ti ON p.PatNum = ti.PatNum
        WHERE ti.InitialType = 0
            AND ti.ToothNum NOT IN (1,16,17,32)
            AND p.PatStatus = 0
        GROUP BY p.PatNum
    )
    SELECT 
        *,
        CASE
            WHEN MissingTeethCount = 1 THEN 'Single Tooth Implant Candidate'
            WHEN MissingTeethCount BETWEEN 2 AND 3 AND MissingTeeth REGEXP '7|8|9|10' THEN 'Anterior Bridge/Implant Candidate'
            WHEN MissingTeethCount BETWEEN 2 AND 4 THEN 'Multiple Implant Candidate'
            WHEN MissingTeethCount > 4 AND MissingTeethCount < 10 THEN 'Full Arch Implant Candidate'
            WHEN MissingTeethCount >= 10 THEN 'All-on-4/6 Candidate'
            ELSE 'Review Needed'
        END as ImplantRecommendation,
        CASE WHEN MissingTeeth REGEXP '7|8|9|10' THEN 'Yes' ELSE 'No' END as HasMissingAnteriorTeeth,
        CASE WHEN MissingTeeth REGEXP '3|14|19|30' THEN 'Yes' ELSE 'No' END as HasMissingFirstMolars
    FROM missing_teeth
) validation
GROUP BY ImplantRecommendation
ORDER BY 
    MIN(MissingTeethCount); 