-- Adjustment Table Validation Queries
-- ==================================

-- AdjType distribution with Sample Notes
SELECT 
    AdjType,
    COUNT(*) as Count,
    COUNT(DISTINCT PatNum) as UniquePatients,
    ROUND(AVG(AdjAmt), 2) as AvgAmount,
    ROUND(SUM(AdjAmt), 2) as TotalAmount,
    MIN(LEFT(AdjNote, 50)) as SampleNote1,
    MAX(LEFT(AdjNote, 50)) as SampleNote2
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
    AND TRIM(AdjNote) != ''
GROUP BY AdjType
ORDER BY Count DESC;

-- Most Common Note Patterns
SELECT 
    AdjType,
    LEFT(TRIM(AdjNote), 50) as NoteSample,
    COUNT(*) as Occurrences,
    COUNT(DISTINCT PatNum) as UniquePatients,
    ROUND(AVG(AdjAmt), 2) as AvgAmount
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
    AND TRIM(AdjNote) != ''
GROUP BY AdjType, LEFT(TRIM(AdjNote), 50)
HAVING Occurrences > 5
ORDER BY AdjType, Occurrences DESC;

-- Provider Distribution with AdjType Counts
SELECT 
    a.ProvNum,
    COALESCE(CONCAT(p.FName, ' ', p.LName), 'No Provider') as ProviderName,
    COUNT(*) as TotalAdjustments,
    COUNT(DISTINCT a.PatNum) as UniquePatients,
    ROUND(SUM(a.AdjAmt), 2) as TotalAmount,
    SUM(CASE WHEN a.AdjType = 188 THEN 1 ELSE 0 END) as Type_188_Count,
    SUM(CASE WHEN a.AdjType = 235 THEN 1 ELSE 0 END) as Type_235_Count,
    SUM(CASE WHEN a.AdjType = 474 THEN 1 ELSE 0 END) as Type_474_Count,
    SUM(CASE WHEN a.AdjType = 186 THEN 1 ELSE 0 END) as Type_186_Count,
    SUM(CASE WHEN a.AdjType = 472 THEN 1 ELSE 0 END) as Type_472_Count
FROM adjustment a
LEFT JOIN provider p ON a.ProvNum = p.ProvNum
WHERE a.AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
GROUP BY a.ProvNum, COALESCE(CONCAT(p.FName, ' ', p.LName), 'No Provider')
ORDER BY TotalAdjustments DESC;



-- 4. Temporal Analysis of Adjustments
SELECT 
    DATE_FORMAT(AdjDate, '%Y-%m') as Month,
    COUNT(*) as TotalAdjustments,
    COUNT(DISTINCT PatNum) as UniquePatients,
    ROUND(AVG(AdjAmt), 2) as AvgAdjustmentAmount,
    ROUND(SUM(AdjAmt), 2) as TotalAdjustmentAmount,
    COUNT(DISTINCT AdjType) as UniqueAdjTypes
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
GROUP BY DATE_FORMAT(AdjDate, '%Y-%m')
ORDER BY Month;


-- Distribution of Adjustments per Patient
SELECT 
    CASE 
        WHEN TotalAdj = 1 THEN '1 adjustment'
        WHEN TotalAdj = 2 THEN '2 adjustments'
        WHEN TotalAdj BETWEEN 3 AND 5 THEN '3-5 adjustments'
        WHEN TotalAdj BETWEEN 6 AND 10 THEN '6-10 adjustments'
        ELSE 'More than 10 adjustments'
    END as AdjustmentGroup,
    COUNT(*) as PatientCount,
    ROUND(AVG(TotalAmount), 2) as AvgTotalAmount
FROM (
    SELECT 
        PatNum,
        COUNT(*) as TotalAdj,
        SUM(AdjAmt) as TotalAmount
    FROM adjustment
    WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
    GROUP BY PatNum
) pat_summary
GROUP BY 
    CASE 
        WHEN TotalAdj = 1 THEN '1 adjustment'
        WHEN TotalAdj = 2 THEN '2 adjustments'
        WHEN TotalAdj BETWEEN 3 AND 5 THEN '3-5 adjustments'
        WHEN TotalAdj BETWEEN 6 AND 10 THEN '6-10 adjustments'
        ELSE 'More than 10 adjustments'
    END
ORDER BY 
    MIN(TotalAdj);

-- 2c. Most Common Note Patterns
SELECT 
    AdjType,
    LEFT(TRIM(AdjNote), 50) as NoteSample,
    COUNT(*) as Occurrences,
    COUNT(DISTINCT PatNum) as UniquePatients,
    ROUND(AVG(AdjAmt), 2) as AvgAmount
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
    AND TRIM(AdjNote) != ''
GROUP BY AdjType, LEFT(TRIM(AdjNote), 50)
HAVING Occurrences > 5
ORDER BY AdjType, Occurrences DESC;


-- Analysis of AdjType Patterns with Procedure Categories
SELECT 
    a.AdjType,
    COUNT(DISTINCT a.AdjNum) as TotalAdjustments,
    ROUND(AVG(ABS(a.AdjAmt)), 2) as AvgAdjustmentAmount,
    ROUND(AVG(UniqueProcedures), 1) as AvgProceduresPerAdj,
    MAX(UniqueProcedures) as MaxProceduresPerAdj
FROM adjustment a
LEFT JOIN (
    SELECT 
        AdjNum,
        COUNT(DISTINCT CodeNum) as UniqueProcedures
    FROM adjustment a2
    JOIN procedurelog pl ON a2.PatNum = pl.PatNum 
        AND pl.ProcDate BETWEEN DATE_SUB(a2.AdjDate, INTERVAL 30 DAY) AND a2.AdjDate
    GROUP BY AdjNum
) proc ON a.AdjNum = proc.AdjNum
WHERE a.AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
    AND UniqueProcedures > 1
GROUP BY a.AdjType
HAVING TotalAdjustments > 5
ORDER BY AvgAdjustmentAmount DESC;

-- Analysis of Multiple Procedures per Adjustment
SELECT 
    a.AdjType,
    a.AdjNum,
    COUNT(DISTINCT pl.CodeNum) as UniqueProcedures,
    COUNT(*) as TotalProcedureLinks,
    ROUND(a.AdjAmt, 2) as AdjustmentAmount,
    GROUP_CONCAT(DISTINCT pc.ProcCode) as ProcedureCodes,
    COUNT(DISTINCT a.PatNum) as UniquePatients
FROM adjustment a
LEFT JOIN procedurelog pl ON a.PatNum = pl.PatNum 
    AND pl.ProcDate BETWEEN DATE_SUB(a.AdjDate, INTERVAL 30 DAY) AND a.AdjDate
LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE a.AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
    AND ABS(a.AdjAmt) >= 1000
GROUP BY a.AdjType, a.AdjNum
HAVING UniqueProcedures > 1
ORDER BY TotalProcedureLinks DESC
LIMIT 100;