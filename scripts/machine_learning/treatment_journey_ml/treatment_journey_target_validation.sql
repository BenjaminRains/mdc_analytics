/*
 * Treatment Journey Target Validation Query
 * 
 * Purpose:
 * Comprehensive analysis of procedure success criteria, payment patterns, and edge cases
 * for the 2024 calendar year.
 * 
 * Output Sections:
 * 1. Threshold Analysis - Payment threshold validation
 * 2. Payment Pattern Analysis - Payment type and split pattern distribution
 * 3. Bundled Procedure Analysis - Zero-fee procedures linked to paid procedures
 * 4. Adjustment Pattern Impact - Effect of adjustments on success
 * 5. Edge Cases - Anomalous success/failure patterns
 * 
 * Metric Definitions:
 * - Metric1: Primary count (varies by section)
 *   • Threshold: Total procedures
 *   • Payment: Case count
 *   • Bundled: Zero-fee count
 *   • Adjustment: Procedures in category
 *   • Edge: Count of cases
 * 
 * - Metric2: Secondary count/rate
 *   • Threshold: Successful procedures
 *   • Payment: Success rate
 *   • Bundled: Related paid count
 *   • Adjustment: Success rate
 *   • Edge: NULL
 * 
 * - Metric3: Success/Pattern metrics
 *   • Threshold: Success rate (%)
 *   • Payment: NULL
 *   • Bundled: Related success rate
 *   • Adjustment: Avg adjustment types
 *   • Edge: NULL
 * 
 * - Metric4: Financial metrics
 *   • Threshold: Avg payment ratio (%)
 *   • Payment: NULL
 *   • Bundled: Avg related fee
 *   • Adjustment: Avg negative adjustments
 *   • Edge: NULL
 * 
 * - Metric5: Pattern analysis
 *   • Threshold: Unique split patterns
 *   • Payment: NULL
 *   • Bundled: NULL
 *   • Adjustment: Avg positive adjustments
 *   • Edge: NULL
 * 
 * - Metric6: Complex patterns
 *   • Threshold: Count of review_needed splits
 *   • Others: NULL
 * 
 * - Metric7: Reserved for future use
 * 
 * Success Criteria:
 * 1. Zero-fee procedures: Completed status and not in excluded codes
 * 2. Paid procedures: Completed status and ≥95% payment ratio
 * 
 * Payment Categories:
 * - administrative_zero_fee: Zero-fee administrative procedures
 * - clinical_zero_fee: Zero-fee clinical procedures
 * - no_payment: No payments recorded
 * - insurance_only: Only insurance payments
 * - direct_only: Only direct payments
 * - both_payment_types: Both insurance and direct payments
 * 
 * Split Patterns:
 * - normal_split: 1-3 splits
 * - complex_split: 4-15 splits
 * - review_needed: >15 splits
 */

WITH 
  -- Common definitions used by multiple sections
  ExcludedCodes AS (
    -- Administrative and non-clinical procedure codes to exclude
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
      -- Documentation/Administrative
      '~GRP~', 'D9987', 'D9986',  -- Notes and cancellations
      'Watch', 'Ztoth',           -- Monitoring
      'D0350',                    -- Photos
      '00040', 'D2919',          -- Post-proc
      '00051',                    -- Scans
      -- Patient Management
      'D9992',                    -- Care coordination
      'D9995', 'D9996',          -- Teledentistry
      -- Evaluations
      'D0190',                    -- Screening
      'D0171',                    -- Re-evaluation
      'D0140',                    -- Limited eval
      'D9430',                    -- Office visit
      'D0120'                     -- Periodic eval
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
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
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
    -- Evaluate payment thresholds and success criteria for 2024
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
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
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
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
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
    WHERE pl1.ProcDate >= '2024-01-01' AND pl1.ProcDate < '2025-01-01'
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
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
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
  )

-- UNION ALL the five output sections and append an ORDER BY clause
SELECT 
    'Threshold Analysis' AS OutputSection,
    threshold_category AS GroupLabel,
    COUNT(*) AS Metric1,                   -- Total procedures
    SUM(target_journey_success) AS Metric2,  -- Successful procedures
    ROUND(AVG(target_journey_success)*100, 2) AS Metric3,  -- Success rate (%)
    ROUND(AVG(payment_ratio_output)*100, 2) AS Metric4,      -- Avg payment ratio (%)
    COUNT(DISTINCT PaymentSplitMetrics.split_pattern) AS Metric5,  -- Unique split patterns
    SUM(CASE WHEN PaymentSplitMetrics.split_pattern = 'review_needed' THEN 1 ELSE 0 END) AS Metric6,
    NULL AS Metric7
FROM ThresholdTests
LEFT JOIN PaymentSplitMetrics ON ThresholdTests.ProcNum = PaymentSplitMetrics.ProcNum
GROUP BY threshold_category

UNION ALL

SELECT 
    'Payment Pattern Analysis' AS OutputSection,
    CONCAT(payment_category, ' - ', split_pattern) AS GroupLabel,
    COUNT(*) AS Metric1,                   -- Case count
    AVG(target_journey_success*1.0) AS Metric2,  -- Success rate
    NULL AS Metric3,
    NULL AS Metric4,
    NULL AS Metric5,
    NULL AS Metric6,
    NULL AS Metric7
FROM PaymentPatterns
GROUP BY payment_category, split_pattern

UNION ALL

SELECT 
    'Bundled Procedure Analysis' AS OutputSection,
    'Bundled Procedures' AS GroupLabel,
    COUNT(DISTINCT zero_fee_proc) AS Metric1,  -- Zero-fee count
    COUNT(DISTINCT paid_proc) AS Metric2,        -- Related paid count
    AVG(related_success*1.0) AS Metric3,         -- Related success rate
    AVG(related_fee) AS Metric4,                 -- Avg related fee
    NULL AS Metric5,
    NULL AS Metric6,
    NULL AS Metric7
FROM BundledProcedures

UNION ALL

SELECT 
    'Adjustment Pattern Impact' AS OutputSection,
    adjustment_category AS GroupLabel,
    COUNT(*) AS Metric1,                       -- Count of procedures in category
    AVG(target_journey_success*1.0) AS Metric2,  -- Success rate
    AVG(unique_adj_types) AS Metric3,          -- Avg adjustment types
    AVG(negative_adj_count) AS Metric4,        -- Avg negative adjustments
    AVG(positive_adj_count) AS Metric5,        -- Avg positive adjustments
    NULL AS Metric6,
    NULL AS Metric7
FROM (
    SELECT 
      CASE 
        WHEN total_adjustment = 0 THEN 'no_adjustments'
        WHEN total_adjustment < 0 THEN 'net_negative'
        ELSE 'net_positive'
      END AS adjustment_category,
      target_journey_success,
      unique_adj_types,
      negative_adj_count,
      positive_adj_count
    FROM AdjustmentPatterns
) AS ap
GROUP BY adjustment_category

UNION ALL

SELECT 
    'Edge Cases' AS OutputSection,
    case_type AS GroupLabel,
    SUM(case_count) AS Metric1,  -- Count of edge cases
    NULL AS Metric2,
    NULL AS Metric3,
    NULL AS Metric4,
    NULL AS Metric5,
    NULL AS Metric6,
    NULL AS Metric7
FROM EdgeCases
WHERE case_type IN ('High ratio failures','Low ratio successes')

ORDER BY OutputSection, GroupLabel;
