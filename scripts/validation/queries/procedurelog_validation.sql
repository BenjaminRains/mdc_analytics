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
 *    - GroupLabel: "{status_id} - {status_name}"
 *    - Metric1: Total procedure count
 *    - Metric2: Percentage of total procedures
 *    - Metric3: Unique patient count
 *    - Metric4: Earliest procedure date
 *    - Metric5: Latest procedure date
 * 
 * 2. Missed/Cancelled Appointment Analysis
 *    - GroupLabel: "{code} - {proc_code} - {description} - ProcStatus:{status}"
 *    - Metric1: Procedure count
 *    - Metric2: Unique patient count
 *    - Metric3: Broken appointment count (AptStatus=5)
 * 
 * 3. Detailed Status Analysis
 *    - GroupLabel: ProcStatus value
 *    - Metric1: Total procedures
 *    - Metric2: Completed procedures
 *    - Metric3: Procedures with appointments
 *    - Metric4: Associated appointment statuses
 * 
 * 4. Appointment Status Overlap Analysis
 *    - GroupLabel: Overlap category (Both/Only AptStatus/Only ProcCode/Neither)
 *    - Metric1: Record count
 *    - Metric2: Percentage of total appointments
 *    - Metric3: Unique patient count
 * 
 * 5. Temporal Analysis
 *    - GroupLabel: "YYYY-MM"
 *    - Metric1: Total procedures
 *    - Metric2: Completed procedures
 *    - Metric3: Missed appointments
 *    - Metric4: Cancelled appointments
 *    - Metric5: Broken appointments
 * 
 * 6. Multiple Recording Pattern Analysis
 *    - GroupLabel: "{PatNum} - {YYYY-MM-DD}"
 *    - Metric1: Distinct procedure count
 *    - Metric2: Status combinations
 *    - Metric3: Missed procedure count
 *    - Metric4: Cancelled procedure count
 *    - Metric5: Broken appointment count
 * 
 * Notes:
 * - All date ranges: 2024-01-01 to 2024-12-31
 * - Missed/Cancelled codes: 626, 764 (missed) and 627, 765 (cancelled)
 * - Status values 1-8 represent standard procedure statuses
 * - GROUP_CONCAT used for status combinations
 */

-- Constants CTE for configuration
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
MissedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN ('D9986', 'D9987')  -- Missed/Cancelled codes
),
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
ThresholdTests AS (
    -- Evaluate payment thresholds per procedure and define success criteria for 2024
    SELECT 
      pl.ProcNum,
      pl.ProcFee,
      COALESCE(pa.total_paid, 0) AS total_paid,
      COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) AS payment_ratio,
      CASE 
        WHEN pl.ProcFee = 0 THEN 'zero_fee'
        WHEN COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.98 THEN 'strict_98'
        WHEN COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95 THEN 'current_95'
        WHEN COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.90 THEN 'lenient_90'
        ELSE 'below_90'
      END AS threshold_category,
      CASE 
        WHEN pl.ProcStatus = 2  
             AND (
                  (pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes))
                  OR 
                  (pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95)
             )
        THEN 1 ELSE 0 END AS target_journey_success,
      COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) AS payment_ratio_output,
      CASE 
        WHEN pl.ProcFee = 0 AND pl.CodeNum IN (SELECT CodeNum FROM ExcludedCodes) THEN 'administrative_zero_fee'
        WHEN pl.ProcFee = 0 THEN 'clinical_zero_fee'
        ELSE 
          CASE 
            WHEN COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.98 THEN 'strict_98'
            WHEN COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95 THEN 'current_95'
            WHEN COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.90 THEN 'lenient_90'
            ELSE 'below_90'
          END
      END AS refined_category,
      DATE_FORMAT(pl.ProcDate, '%Y-%m') AS proc_month,
      pl.ProvNum
    FROM procedurelog pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcDate >= '2024-01-01' 
      AND pl.ProcDate < '2025-01-01'
),
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

-- Main queries with improved labeling
SELECT 
    'Overall ProcStatus Distribution' AS OutputSection,
    CONCAT(s.status_id, ' - ', s.status_name) AS GroupLabel,
    COUNT(*) AS Metric1,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS Metric2,
    COUNT(DISTINCT pl.PatNum) AS Metric3,
    MIN(pl.ProcDate) AS Metric4,
    MAX(pl.ProcDate) AS Metric5,
    NULL AS Metric6,
    NULL AS Metric7
FROM procedurelog pl
JOIN StatusCodes s ON pl.ProcStatus = s.status_id
WHERE pl.ProcDate >= '2024-01-01' 
    AND pl.ProcDate < '2025-01-01'
GROUP BY s.status_id, s.status_name

UNION ALL

SELECT 
    'Missed/Cancelled Appointment Analysis' AS OutputSection,
    CONCAT(pc.CodeNum, ' - ', pc.ProcCode, ' - ', pc.Descript, ' - ProcStatus:', pl.ProcStatus) AS GroupLabel,
    COUNT(*) AS Metric1,
    COUNT(DISTINCT pl.PatNum) AS Metric2,
    COUNT(DISTINCT CASE WHEN a.AptStatus = 5 THEN pl.ProcNum END) AS Metric3,
    NULL AS Metric4,
    NULL AS Metric5,
    NULL AS Metric6,
    NULL AS Metric7
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
LEFT JOIN appointment a ON pl.AptNum = a.AptNum
WHERE pc.CodeNum IN (626, 764, 627, 765)
  AND pl.ProcDate >= '2024-01-01'
  AND pl.ProcDate < '2025-01-01'
GROUP BY pc.CodeNum, pc.ProcCode, pc.Descript, pl.ProcStatus

UNION ALL

SELECT 
    'Detailed Status Analysis' AS OutputSection,
    CAST(ProcStatus AS CHAR) AS GroupLabel,
    COUNT(*) AS Metric1,
    SUM(CASE WHEN WasCompleted = 'Yes' THEN 1 ELSE 0 END) AS Metric2,
    SUM(CASE WHEN HasAppointment = 'Yes' THEN 1 ELSE 0 END) AS Metric3,
    GROUP_CONCAT(DISTINCT AptStatus SEPARATOR ', ') AS Metric4,
    NULL AS Metric5,
    NULL AS Metric6,
    NULL AS Metric7
FROM SampleProcs
GROUP BY ProcStatus

UNION ALL

SELECT 
    'Appointment Status Overlap Analysis' AS OutputSection,
    CASE 
      WHEN a.AptStatus = 5 AND pl.CodeNum IN (626, 764, 627, 765) THEN 'Both'
      WHEN a.AptStatus = 5 THEN 'Only AptStatus'
      WHEN pl.CodeNum IN (626, 764, 627, 765) THEN 'Only ProcCode'
      ELSE 'Neither'
    END AS GroupLabel,
    COUNT(*) AS Metric1,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) 
           FROM appointment 
           WHERE AptDateTime >= '2024-01-01' AND AptDateTime < '2025-01-01'
             AND (AptStatus = 5 OR AptStatus IS NOT NULL)), 2) AS Metric2,
    COUNT(DISTINCT a.PatNum) AS Metric3,
    NULL AS Metric4,
    NULL AS Metric5,
    NULL AS Metric6,
    NULL AS Metric7
FROM appointment a
LEFT JOIN procedurelog pl ON a.AptNum = pl.AptNum
WHERE a.AptDateTime >= '2024-01-01'
  AND a.AptDateTime < '2025-01-01'
  AND (a.AptStatus = 5 OR pl.CodeNum IN (626, 764, 627, 765))
GROUP BY 
  CASE 
    WHEN a.AptStatus = 5 AND pl.CodeNum IN (626, 764, 627, 765) THEN 'Both'
    WHEN a.AptStatus = 5 THEN 'Only AptStatus'
    WHEN pl.CodeNum IN (626, 764, 627, 765) THEN 'Only ProcCode'
    ELSE 'Neither'
  END

UNION ALL

SELECT 
    'Temporal Analysis' AS OutputSection,
    CONCAT(YEAR(pl.ProcDate), '-', LPAD(MONTH(pl.ProcDate), 2, '0')) AS GroupLabel,
    COUNT(*) AS Metric1,
    COUNT(CASE WHEN pl.ProcStatus = 2 THEN 1 END) AS Metric2,
    COUNT(CASE WHEN pl.CodeNum IN (626, 764) THEN 1 END) AS Metric3,
    COUNT(CASE WHEN pl.CodeNum IN (627, 765) THEN 1 END) AS Metric4,
    COUNT(DISTINCT CASE WHEN a.AptStatus = 5 THEN a.AptNum END) AS Metric5,
    NULL AS Metric6,
    NULL AS Metric7
FROM procedurelog pl
LEFT JOIN appointment a ON pl.AptNum = a.AptNum
WHERE pl.ProcDate >= '2024-01-01'
  AND pl.ProcDate < '2025-01-01'
GROUP BY YEAR(pl.ProcDate), MONTH(pl.ProcDate)

UNION ALL

SELECT 
    'Multiple Recording Pattern Analysis' AS OutputSection,
    CONCAT(pl.PatNum, ' - ', DATE_FORMAT(pl.ProcDate, '%Y-%m-%d')) AS GroupLabel,
    COUNT(DISTINCT pl.ProcNum) AS Metric1,
    GROUP_CONCAT(DISTINCT CAST(pl.ProcStatus AS CHAR) SEPARATOR ', ') AS Metric2,
    COUNT(DISTINCT CASE WHEN pl.CodeNum IN (626, 764) THEN pl.ProcNum END) AS Metric3,
    COUNT(DISTINCT CASE WHEN pl.CodeNum IN (627, 765) THEN pl.ProcNum END) AS Metric4,
    COUNT(DISTINCT CASE WHEN a.AptStatus = 5 THEN a.AptNum END) AS Metric5,
    NULL AS Metric6,
    NULL AS Metric7
FROM procedurelog pl
LEFT JOIN appointment a ON pl.AptNum = a.AptNum
WHERE pl.ProcDate >= '2024-01-01'
  AND pl.ProcDate < '2025-01-01'
GROUP BY pl.PatNum, pl.ProcDate
HAVING COUNT(DISTINCT pl.ProcNum) > 1

ORDER BY 
    CASE OutputSection
        WHEN 'Overall ProcStatus Distribution' THEN 1
        WHEN 'Missed/Cancelled Appointment Analysis' THEN 2
        WHEN 'Detailed Status Analysis' THEN 3
        WHEN 'Appointment Status Overlap Analysis' THEN 4
        WHEN 'Temporal Analysis' THEN 5
        WHEN 'Multiple Recording Pattern Analysis' THEN 6
    END,
    GroupLabel;
