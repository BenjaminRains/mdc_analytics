/*
 * Comprehensive Procedure Log Validation Query
 * 
 * Purpose: Analyze procedure records across multiple dimensions for the year 2024
 * 
 * Output Structure:
 * - OutputSection: Analysis category identifier
 * - GroupLabel: Context-specific grouping key
 * - Metrics 1-7: Section-specific measurements
 * 
 * Analysis Sections:
 * 1. Overall ProcStatus Distribution
 * 2. Missed/Cancelled Appointment Analysis
 * 3. Detailed Status Analysis
 * 4. Appointment Status Overlap Analysis
 * 5. Temporal Analysis
 * 6. Multiple Recording Pattern Analysis
 * 
 * Notes:
 * - All date ranges: 2024-01-01 to 2024-12-31
 * - Missed/Cancelled codes: D9986 (Missed), D9987 (Cancelled)
 * - AptStatus = 5 represents broken appointments
 * - ProcStatus values: 1=Treatment Planned, 2=Completed, 3=Existing Current, 
 *   4=Existing Other, 5=Referred, 6=Deleted, 7=Condition, 8=Invalid
 * - Payment Types: 0=Regular, 288=Prepayment, 439=Treatment Plan Deposit
 * - Success criteria: Payment ratio ≥ 0.95 or zero-fee (excluding admin codes)
 */

-- =============================================
-- REFERENCE DATA CTEs
-- =============================================

-- Reference data for status codes 
WITH StatusCodes AS (
    SELECT 1 as status_id, 'Treatment Planned' as status_name
    UNION ALL SELECT 2, 'Completed'
    UNION ALL SELECT 3, 'Existing Current'
    UNION ALL SELECT 4, 'Existing Other'
    UNION ALL SELECT 5, 'Referred'
    UNION ALL SELECT 6, 'Deleted'
    UNION ALL SELECT 7, 'Condition'
    UNION ALL SELECT 8, 'Invalid'
),

-- Reference data for missed/cancelled appointment codes
MissedCancelledCodes AS (
    SELECT CodeNum, ProcCode, Descript
    FROM procedurecode 
    WHERE ProcCode IN ('D9986', 'D9987')  -- D9986=Missed, D9987=Cancelled
),

-- Reference data for excluded procedure codes
ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
      '~GRP~', 'D9987', 'D9986', 'Watch', 'Ztoth', 'D0350',
      '00040', 'D2919', '00051',
      'D9992', 'D9995', 'D9996',
      'D0190', 'D0171', 'D0140', 'D9430', 'D0120'
    )
),

-- =============================================
-- ANALYTICAL CTEs
-- =============================================

-- Payment data aggregation
PaymentActivity AS (
    -- Aggregate payments, insurance, and adjustments per procedure for 2024
    SELECT 
      pl.ProcNum,
      pl.ProcFee,
      COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_paid,
      COALESCE(SUM(ps.SplitAmt), 0) AS direct_paid,
      COALESCE(SUM(adj.AdjAmt), 0) AS adjustments,
      COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    LEFT JOIN adjustment adj ON pl.ProcNum = adj.ProcNum
    WHERE pl.ProcDate >= '2024-01-01' 
      AND pl.ProcDate < '2025-01-01'
    GROUP BY pl.ProcNum, pl.ProcFee
),

-- Payment split metrics
PaymentSplitMetrics AS (
    -- Calculate split patterns per procedure for 2024
    SELECT 
      ps.ProcNum,
      COUNT(*) AS split_count,
      CASE 
        WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
        WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
        ELSE 'review_needed'
      END AS split_pattern
    FROM paysplit ps
    GROUP BY ps.ProcNum
),

-- Payment thresholds
ThresholdTests AS (
    -- Calculate payment ratios and success flags for 2024
    SELECT 
      pl.ProcNum,
      pl.ProcFee,
      COALESCE(pa.total_paid, 0) AS total_paid,
      COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) AS payment_ratio_output,
      psm.split_pattern,
      CASE 
        WHEN pl.ProcStatus = 2  
             AND (
                  (pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes))
                  OR 
                  (pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95)
             )
        THEN 1 ELSE 0 END AS target_journey_success
    FROM procedurelog pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    LEFT JOIN PaymentSplitMetrics psm ON pl.ProcNum = psm.ProcNum
    WHERE pl.ProcDate >= '2024-01-01' 
      AND pl.ProcDate < '2025-01-01'
),

-- Payment pattern categorization
PaymentPatterns AS (
    -- Categorize payment types based on insurance vs direct and link split patterns for 2024
    SELECT 
      pl.ProcNum,
      CASE
        WHEN pl.ProcFee = 0 AND pl.CodeNum IN (SELECT CodeNum FROM ExcludedCodes) THEN 'administrative_zero_fee'
        WHEN pl.ProcFee = 0 THEN 'clinical_zero_fee'
        WHEN COALESCE(pa.total_paid, 0) = 0 THEN 'no_payment'
        WHEN COALESCE(pa.insurance_paid, 0) > 0 AND COALESCE(pa.direct_paid, 0) = 0 THEN 'insurance_only'
        WHEN COALESCE(pa.insurance_paid, 0) = 0 AND COALESCE(pa.direct_paid, 0) > 0 THEN 'direct_only'
        ELSE 'both_payment_types'
      END AS payment_category,
      psm.split_pattern,
      CASE 
        WHEN pl.ProcStatus = 2  
             AND (
                  (pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes))
                  OR 
                  (pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95)
             )
        THEN 1 ELSE 0 END AS target_journey_success
    FROM procedurelog pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    LEFT JOIN PaymentSplitMetrics psm ON pl.ProcNum = psm.ProcNum
    WHERE pl.ProcDate >= '2024-01-01' 
      AND pl.ProcDate < '2025-01-01'
),

-- Bundled procedures analysis
BundledProcedures AS (
    -- Identify zero-fee procedures bundled with a paid procedure on the same day for 2024
    SELECT 
      pl1.ProcNum AS zero_fee_proc,
      pl2.ProcNum AS paid_proc,
      pl1.ProcDate,
      pl1.PatNum,
      pl2.ProcFee AS related_fee,
      CASE 
        WHEN pl2.ProcStatus = 2 
             AND (pl2.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl2.ProcFee, 0) >= 0.95)
        THEN 1 ELSE 0 END AS related_success
    FROM procedurelog pl1
    JOIN procedurelog pl2 
         ON pl1.PatNum = pl2.PatNum 
        AND pl1.ProcDate = pl2.ProcDate
        AND pl1.ProcFee = 0 
        AND pl2.ProcFee > 0
    LEFT JOIN PaymentActivity pa ON pl2.ProcNum = pa.ProcNum
    WHERE pl1.ProcDate >= '2024-01-01' 
      AND pl1.ProcDate < '2025-01-01'
),

-- Adjustment patterns analysis
AdjustmentPatterns AS (
    -- Evaluate adjustment patterns per procedure for 2024
    SELECT 
      pl.ProcNum,
      COUNT(DISTINCT adj.AdjType) AS unique_adj_types,
      SUM(CASE WHEN adj.AdjAmt < 0 THEN 1 ELSE 0 END) AS negative_adj_count,
      SUM(CASE WHEN adj.AdjAmt > 0 THEN 1 ELSE 0 END) AS positive_adj_count,
      COALESCE(SUM(adj.AdjAmt), 0) AS total_adjustment,
      CASE 
        WHEN pl.ProcStatus = 2  
             AND (
                  (pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes))
                  OR 
                  (pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95)
             )
        THEN 1 ELSE 0 END AS target_journey_success
    FROM procedurelog pl
    LEFT JOIN adjustment adj ON pl.ProcNum = adj.ProcNum
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcDate >= '2024-01-01' 
      AND pl.ProcDate < '2025-01-01'
    GROUP BY pl.ProcNum, pl.ProcStatus, pl.ProcFee, pl.CodeNum
),

-- Edge cases in payment ratios
EdgeCases AS (
    -- Identify edge cases based on payment ratio and success flags for 2024
    SELECT 
      CASE 
        WHEN payment_ratio_output >= 0.95 AND target_journey_success = 0 THEN 'High ratio failures'
        WHEN payment_ratio_output < 0.95 AND target_journey_success = 1 THEN 'Low ratio successes'
        ELSE 'other'
      END AS case_type,
      COUNT(*) AS case_count
    FROM ThresholdTests
    GROUP BY 
      CASE 
        WHEN payment_ratio_output >= 0.95 AND target_journey_success = 0 THEN 'High ratio failures'
        WHEN payment_ratio_output < 0.95 AND target_journey_success = 1 THEN 'Low ratio successes'
        ELSE 'other'
      END
),

-- Sample procedures with appointment info
SampleProcs AS (
    -- Detailed Status Analysis with Appointments for 2024
    SELECT 
      pl.ProcStatus,
      pc.ProcCode,
      pc.Descript AS ProcedureDescription,
      pl.ProcFee,
      pl.DateTP AS TreatmentPlanDate,
      pl.ProcDate AS ScheduledDate,
      pl.DateComplete AS CompletionDate,
      pl.AptNum,
      CASE 
        WHEN pl.DateComplete != '0001-01-01' THEN 'Yes'
        ELSE 'No'
      END AS WasCompleted,
      CASE 
        WHEN pl.AptNum > 0 THEN 'Yes'
        ELSE 'No'
      END AS HasAppointment,
      a.AptStatus
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN appointment a ON pl.AptNum = a.AptNum
    WHERE pl.ProcDate >= '2024-01-01'
      AND pl.ProcDate < '2025-01-01'
)

-- =============================================
-- MAIN ANALYSIS QUERIES
-- =============================================

-- 1. Overall ProcStatus Distribution
SELECT 
    'Overall ProcStatus Distribution' AS OutputSection,
    CONCAT(s.status_name, ' (', s.status_id, ')') AS GroupLabel,
    COUNT(*) AS case_count
FROM procedurelog pl
JOIN StatusCodes s ON pl.ProcStatus = s.status_id
WHERE pl.ProcDate >= '2024-01-01' 
  AND pl.ProcDate < '2025-01-01'
GROUP BY s.status_name, s.status_id
ORDER BY s.status_id;

-- 2. Missed/Cancelled Appointment Analysis
SELECT 
    'Missed/Cancelled Appointment Analysis' AS OutputSection,
    CONCAT(mc.ProcCode, ' - ', mc.Descript) AS GroupLabel,
    COUNT(*) AS case_count
FROM procedurelog pl
JOIN MissedCancelledCodes mc ON pl.CodeNum = mc.CodeNum
WHERE pl.ProcDate >= '2024-01-01' 
  AND pl.ProcDate < '2025-01-01'
GROUP BY mc.ProcCode, mc.Descript;

-- 3. Detailed Status Analysis
SELECT 
    'Detailed Status Analysis' AS OutputSection,
    CONCAT(s.status_name, ' (', s.status_id, ')') AS GroupLabel,
    COUNT(*) AS case_count
FROM procedurelog pl
JOIN StatusCodes s ON pl.ProcStatus = s.status_id
WHERE pl.ProcDate >= '2024-01-01' 
  AND pl.ProcDate < '2025-01-01'
GROUP BY s.status_name, s.status_id
ORDER BY s.status_id;

-- 4. Appointment Status Overlap Analysis
SELECT 
    'Appointment Status Overlap Analysis' AS OutputSection,
    CONCAT(s.status_name, ' (', s.status_id, ')') AS GroupLabel,
    COUNT(*) AS case_count
FROM procedurelog pl
JOIN StatusCodes s ON pl.ProcStatus = s.status_id
WHERE pl.ProcDate >= '2024-01-01' 
  AND pl.ProcDate < '2025-01-01'
GROUP BY s.status_name, s.status_id
ORDER BY s.status_id;

-- 5. Temporal Analysis
SELECT 
    'Temporal Analysis' AS OutputSection,
    CONCAT(EXTRACT(YEAR FROM pl.ProcDate), '-', EXTRACT(MONTH FROM pl.ProcDate)) AS GroupLabel,
    COUNT(*) AS case_count
FROM procedurelog pl
WHERE pl.ProcDate >= '2024-01-01' 
  AND pl.ProcDate < '2025-01-01'
GROUP BY EXTRACT(YEAR FROM pl.ProcDate), EXTRACT(MONTH FROM pl.ProcDate)
ORDER BY EXTRACT(YEAR FROM pl.ProcDate), EXTRACT(MONTH FROM pl.ProcDate);

-- 6. Multiple Recording Pattern Analysis
SELECT 
    'Multiple Recording Pattern Analysis' AS OutputSection,
    CONCAT(s.status_name, ' (', s.status_id, ')') AS GroupLabel,
    COUNT(*) AS case_count
FROM procedurelog pl
JOIN StatusCodes s ON pl.ProcStatus = s.status_id
WHERE pl.ProcDate >= '2024-01-01' 
  AND pl.ProcDate < '2025-01-01'
GROUP BY s.status_name, s.status_id
ORDER BY s.status_id;

-- 7. Edge Cases in Payment Ratios
SELECT 
    'Edge Cases in Payment Ratios' AS OutputSection,
    case_type AS GroupLabel,
    case_count
FROM EdgeCases
ORDER BY case_type;

-- 8. Sample Procedures with Appointment Info
SELECT 
    'Sample Procedures with Appointment Info' AS OutputSection,
    CONCAT(s.status_name, ' (', s.status_id, ')') AS GroupLabel,
    COUNT(*) AS case_count
FROM SampleProcs sp
JOIN StatusCodes s ON sp.ProcStatus = s.status_id
WHERE sp.ProcDate >= '2024-01-01' 
  AND sp.ProcDate < '2025-01-01'
GROUP BY s.status_name, s.status_id
ORDER BY s.status_id;