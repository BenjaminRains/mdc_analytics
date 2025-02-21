/*
 * Unified Adjustment Validation Query
 *
 * Purpose:
 * - Combine all adjustment-related analyses into a single dataset
 * - Standardize output format for easier processing
 * - Include both general and insurance-specific metrics
 * - Enable trend analysis across multiple dimensions
 *
 * Output Format:
 * - MetricCategory: Type of analysis being performed
 * - GroupingValue: Key for the specific group being analyzed
 * - CountMetric: Primary count metric for the group
 * - UniquePatients: Number of distinct patients
 * - AvgAmount: Average monetary amount
 * - TotalAmount: Total monetary amount
 * - SampleNote1/2: Example notes where applicable
 * - AdditionalInfo: JSON-style string of extra metrics
 *
 * Categories:
 * 1. General Adjustments:
 *    - AdjTypeDistribution
 *    - NotePatterns
 *    - ProviderDistribution
 *    - TemporalAnalysis
 *    - PatientDistribution
 *
 * 2. Procedure Analysis:
 *    - AdjTypeProcedure
 *    - MultipleProcedures
 *
 * 3. Insurance Analysis:
 *    - CarrierAdjustments
 *    - ClaimWriteOffDiscrepancy
 *    - CarrierPaymentTrends
 *    - CarrierAdjustmentPayment
 *    - AdjustmentTimeTrends
 */

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_adj_date ON adjustment(AdjDate);
CREATE INDEX IF NOT EXISTS idx_claim_date ON claim(DateService);
CREATE INDEX IF NOT EXISTS idx_proc_date ON procedurelog(ProcDate);

WITH DateParams AS (
    SELECT DATE_SUB(CURDATE(), INTERVAL 2 YEAR) as start_date,
           CURDATE() as end_date
)

-- Unified Adjustment Validation Output (Including Insurance-Related Analyses)
-- Each SELECT returns the same columns so that they can be combined via UNION ALL.

SELECT 
    'AdjTypeDistribution' AS MetricCategory,
    CAST(AdjType AS CHAR) AS GroupingValue,
    COUNT(*) AS CountMetric,
    COUNT(DISTINCT PatNum) AS UniquePatients,
    ROUND(AVG(AdjAmt), 2) AS AvgAmount,
    ROUND(SUM(AdjAmt), 2) AS TotalAmount,
    MIN(LEFT(AdjNote, 50)) AS SampleNote1,
    MAX(LEFT(AdjNote, 50)) AS SampleNote2,
    NULL AS AdditionalInfo
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
  AND TRIM(AdjNote) != ''
GROUP BY AdjType

UNION ALL

-- Most Common Note Patterns
SELECT 
    'NotePatterns' AS MetricCategory,
    CONCAT(AdjType, ' - ', LEFT(TRIM(AdjNote), 50)) AS GroupingValue,
    COUNT(*) AS CountMetric,
    COUNT(DISTINCT PatNum) AS UniquePatients,
    ROUND(AVG(AdjAmt), 2) AS AvgAmount,
    NULL AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    NULL AS AdditionalInfo
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
  AND TRIM(AdjNote) != ''
GROUP BY AdjType, LEFT(TRIM(AdjNote), 50)
HAVING COUNT(*) > 5

UNION ALL

-- Provider Distribution with AdjType Counts
SELECT 
    'ProviderDistribution' AS MetricCategory,
    COALESCE(CONCAT(p.FName, ' ', p.LName), 'No Provider') AS GroupingValue,
    COUNT(*) AS CountMetric,
    COUNT(DISTINCT a.PatNum) AS UniquePatients,
    NULL AS AvgAmount,
    ROUND(SUM(a.AdjAmt), 2) AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    CONCAT(
         'Type_188:', SUM(CASE WHEN a.AdjType = 188 THEN 1 ELSE 0 END),
         '; Type_235:', SUM(CASE WHEN a.AdjType = 235 THEN 1 ELSE 0 END),
         '; Type_474:', SUM(CASE WHEN a.AdjType = 474 THEN 1 ELSE 0 END),
         '; Type_186:', SUM(CASE WHEN a.AdjType = 186 THEN 1 ELSE 0 END),
         '; Type_472:', SUM(CASE WHEN a.AdjType = 472 THEN 1 ELSE 0 END)
    ) AS AdditionalInfo
FROM adjustment a
LEFT JOIN provider p ON a.ProvNum = p.ProvNum
WHERE a.AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
GROUP BY a.ProvNum, COALESCE(CONCAT(p.FName, ' ', p.LName), 'No Provider')

UNION ALL

-- Temporal Analysis of Adjustments
SELECT 
    'TemporalAnalysis' AS MetricCategory,
    DATE_FORMAT(AdjDate, '%Y-%m') AS GroupingValue,
    COUNT(*) AS CountMetric,
    COUNT(DISTINCT PatNum) AS UniquePatients,
    ROUND(AVG(AdjAmt), 2) AS AvgAmount,
    ROUND(SUM(AdjAmt), 2) AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    CONCAT('UniqueAdjTypes:', COUNT(DISTINCT AdjType)) AS AdditionalInfo
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
GROUP BY DATE_FORMAT(AdjDate, '%Y-%m')

UNION ALL

-- Distribution of Adjustments per Patient
SELECT 
    'PatientDistribution' AS MetricCategory,
    AdjustmentGroup AS GroupingValue,
    COUNT(*) AS CountMetric,
    NULL AS UniquePatients,
    ROUND(AVG(TotalAmount), 2) AS AvgAmount,
    NULL AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    NULL AS AdditionalInfo
FROM (
    SELECT 
        PatNum,
        COUNT(*) AS TotalAdj,
        SUM(AdjAmt) AS TotalAmount,
        CASE 
            WHEN COUNT(*) = 1 THEN '1 adjustment'
            WHEN COUNT(*) = 2 THEN '2 adjustments'
            WHEN COUNT(*) BETWEEN 3 AND 5 THEN '3-5 adjustments'
            WHEN COUNT(*) BETWEEN 6 AND 10 THEN '6-10 adjustments'
            ELSE 'More than 10 adjustments'
        END AS AdjustmentGroup
    FROM adjustment
    WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
    GROUP BY PatNum
) pat_summary
GROUP BY AdjustmentGroup

UNION ALL

-- Analysis of AdjType Patterns with Procedure Categories
SELECT 
    'AdjTypeProcedure' AS MetricCategory,
    CAST(a.AdjType AS CHAR) AS GroupingValue,
    COUNT(DISTINCT a.AdjNum) AS CountMetric,
    NULL AS UniquePatients,
    ROUND(AVG(ABS(a.AdjAmt)), 2) AS AvgAmount,
    NULL AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    CONCAT('AvgProcedures:', ROUND(AVG(UniqueProcedures), 1),
           '; MaxProcedures:', MAX(UniqueProcedures)) AS AdditionalInfo
FROM adjustment a
LEFT JOIN (
    SELECT 
        AdjNum,
        COUNT(DISTINCT CodeNum) AS UniqueProcedures
    FROM adjustment a2
    JOIN procedurelog pl ON a2.PatNum = pl.PatNum 
         AND pl.ProcDate BETWEEN DATE_SUB(a2.AdjDate, INTERVAL 30 DAY) AND a2.AdjDate
    GROUP BY AdjNum
) proc ON a.AdjNum = proc.AdjNum
WHERE a.AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
    AND (proc.UniqueProcedures > 1 OR proc.UniqueProcedures IS NOT NULL)
GROUP BY a.AdjType
HAVING COUNT(DISTINCT a.AdjNum) > 5

UNION ALL

-- Analysis of Multiple Procedures per Adjustment
SELECT 
    'MultipleProcedures' AS MetricCategory,
    CONCAT(a.AdjType, ' - ', a.AdjNum) AS GroupingValue,
    COUNT(DISTINCT pl.CodeNum) AS CountMetric,
    COUNT(DISTINCT a.PatNum) AS UniquePatients,
    ROUND(a.AdjAmt, 2) AS AvgAmount,
    NULL AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    CONCAT('ProcedureCodes: ', GROUP_CONCAT(DISTINCT pc.ProcCode SEPARATOR ', ')) AS AdditionalInfo
FROM adjustment a
LEFT JOIN procedurelog pl ON a.PatNum = pl.PatNum 
    AND pl.ProcDate BETWEEN DATE_SUB(a.AdjDate, INTERVAL 30 DAY) AND a.AdjDate
LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE a.AdjDate >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
    AND ABS(a.AdjAmt) >= 1000
GROUP BY a.AdjType, a.AdjNum

UNION ALL

-- Insurance-Related Queries
-- 1. Insurance Plans that Consistently Require Adjustments
SELECT 
    'CarrierAdjustments' AS MetricCategory,
    carr.CarrierName AS GroupingValue,
    COUNT(DISTINCT a.AdjNum) AS CountMetric,
    NULL AS UniquePatients,
    AVG(cl.InsPayAmt) AS AvgAmount,
    SUM(a.AdjAmt) AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    CONCAT('NumClaims:', COUNT(DISTINCT cl.ClaimNum),
           '; TotalWriteOffs:', SUM(cl.WriteOff)) AS AdditionalInfo
FROM adjustment a
JOIN claim cl ON a.PatNum = cl.PatNum 
    AND a.ProcDate = cl.DateService
JOIN carrier carr ON cl.PlanNum = carr.CarrierNum
WHERE cl.ClaimStatus != ''
GROUP BY carr.CarrierName
HAVING COUNT(DISTINCT a.AdjNum) > 0

UNION ALL

-- 2. Verify that insurance write-offs don't exceed claim limits (summary)
SELECT 
    'ClaimWriteOffDiscrepancy' AS MetricCategory,
    'All Claims' AS GroupingValue,
    COUNT(*) AS CountMetric,
    NULL AS UniquePatients,
    ROUND(AVG(cp.InsPayAmt + cp.WriteOff - cp.FeeBilled), 2) AS AvgAmount,
    NULL AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    CONCAT('DiscrepancyCount:', COUNT(*)) AS AdditionalInfo
FROM claimproc cp
JOIN claim c ON cp.ClaimNum = c.ClaimNum
WHERE cp.FeeBilled <> (cp.InsPayAmt + cp.WriteOff)

UNION ALL

-- 3. Long-term Claim Payment Trends per Carrier
SELECT 
    'CarrierPaymentTrends' AS MetricCategory,
    CONCAT(c.CarrierName, ' - ', YEAR(cl.DateService)) AS GroupingValue,
    COUNT(cl.ClaimNum) AS CountMetric,
    NULL AS UniquePatients,
    AVG(cl.InsPayAmt) AS AvgAmount,
    NULL AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    NULL AS AdditionalInfo
FROM carrier c
JOIN claim cl ON cl.PlanNum = c.CarrierNum
WHERE cl.ClaimStatus != ''
    AND cl.DateService IS NOT NULL
GROUP BY c.CarrierNum, c.CarrierName, YEAR(cl.DateService)

UNION ALL

-- 4. Consolidated Carrier Adjustment Analysis with Payment Trends
SELECT 
    'CarrierAdjustmentPayment' AS MetricCategory,
    carr.CarrierName AS GroupingValue,
    COUNT(DISTINCT a.AdjNum) AS CountMetric,
    NULL AS UniquePatients,
    AVG(cl.InsPayAmt) AS AvgAmount,
    SUM(a.AdjAmt) AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    CONCAT('PaymentDiscrepancies:', SUM(CASE WHEN cl.ClaimFee <> (cl.InsPayAmt + cl.WriteOff) THEN 1 ELSE 0 END)) AS AdditionalInfo
FROM adjustment a
JOIN claim cl ON a.PatNum = cl.PatNum 
    AND a.ProcDate = cl.DateService
JOIN carrier carr ON cl.PlanNum = carr.CarrierNum
WHERE cl.ClaimStatus != ''
GROUP BY carr.CarrierName
HAVING SUM(CASE WHEN cl.ClaimFee <> (cl.InsPayAmt + cl.WriteOff) THEN 1 ELSE 0 END) > 0

UNION ALL

-- 5. Track Adjustment Patterns Over Time
SELECT 
    'AdjustmentTimeTrends' AS MetricCategory,
    CONCAT(carr.CarrierName, ' - ', DATE_FORMAT(a.AdjDate, '%Y-%m')) AS GroupingValue,
    COUNT(DISTINCT a.AdjNum) AS CountMetric,
    NULL AS UniquePatients,
    AVG(ibb.InsPayAmt) AS AvgAmount,
    SUM(a.AdjAmt) AS TotalAmount,
    NULL AS SampleNote1,
    NULL AS SampleNote2,
    CONCAT('FeeOverrides:', COUNT(DISTINCT ibbl.InsBlueBookLogNum)) AS AdditionalInfo
FROM adjustment a
JOIN claim cl ON a.PatNum = cl.PatNum 
    AND a.ProcDate = cl.DateService
JOIN carrier carr ON cl.PlanNum = carr.CarrierNum
LEFT JOIN insbluebook ibb ON carr.CarrierNum = ibb.CarrierNum
    AND cl.PlanNum = ibb.PlanNum
    AND DATE_FORMAT(a.AdjDate, '%Y-%m') = DATE_FORMAT(ibb.ProcDate, '%Y-%m')
LEFT JOIN insbluebooklog ibbl ON ibb.ClaimNum = cl.ClaimNum
WHERE cl.ClaimStatus != ''
GROUP BY carr.CarrierName, DATE_FORMAT(a.AdjDate, '%Y-%m')

ORDER BY MetricCategory, GroupingValue;
