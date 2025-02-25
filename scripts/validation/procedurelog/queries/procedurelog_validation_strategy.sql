/*
 * ProcedureLog Validation Strategy
 * 
 * Purpose: Systematic testing approach for procedurelog validation queries
 * Scope: 2024 data only (Jan 1 - Dec 31, 2024)
 * 
 * This file contains the testing strategy and queries for validating procedurelog data
 * in a progressive manner from high-level overview to low-level detailed analysis.
 */

-- =============================================
-- PHASE 1: DATA AVAILABILITY AND BASIC INTEGRITY
-- =============================================

-- 1.1: Schema Validation
-- Purpose: Confirm key fields exist and have expected data types
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'procedurelog';

-- 1.2: Foreign Key Validation
-- Purpose: Check foreign key relationships
SELECT COUNT(*) FROM procedurelog pl
LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE pc.CodeNum IS NULL AND pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01';

-- 1.3: Volume Testing
-- Purpose: Check basic counts and date ranges
SELECT 
    COUNT(*) AS total_records,
    MIN(ProcDate) AS earliest_date,
    MAX(ProcDate) AS latest_date,
    COUNT(DISTINCT PatNum) AS unique_patients
FROM procedurelog
WHERE ProcDate >= '2024-01-01' AND ProcDate < '2025-01-01';

-- 1.4: Status Distribution
-- Purpose: Verify status distribution 
SELECT 
    ProcStatus,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM procedurelog
WHERE ProcDate >= '2024-01-01' AND ProcDate < '2025-01-01'
GROUP BY ProcStatus
ORDER BY ProcStatus;

-- =============================================
-- PHASE 2: RELATIONSHIP TESTING
-- =============================================

-- 2.1: Appointment Relationships
-- Purpose: Test appointment joins and statistics
SELECT 
    COUNT(*) AS total_procs,
    SUM(CASE WHEN pl.AptNum > 0 THEN 1 ELSE 0 END) AS has_appointment_num,
    SUM(CASE WHEN apt.AptNum IS NOT NULL THEN 1 ELSE 0 END) AS appointment_exists,
    SUM(CASE WHEN pl.AptNum > 0 AND apt.AptNum IS NULL THEN 1 ELSE 0 END) AS orphaned_appointment_refs,
    SUM(CASE WHEN apt.AptStatus = 5 THEN 1 ELSE 0 END) AS broken_appointments
FROM procedurelog pl
LEFT JOIN appointment apt ON pl.AptNum = apt.AptNum
WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01';

-- 2.2: Payment Table Relationships
-- Purpose: Test payment table relationships
SELECT 
    COUNT(DISTINCT pl.ProcNum) AS total_procedures,
    COUNT(DISTINCT cp.ProcNum) AS with_claimproc,
    ROUND(100.0 * COUNT(DISTINCT cp.ProcNum) / COUNT(DISTINCT pl.ProcNum), 2) AS claimproc_pct,
    COUNT(DISTINCT ps.ProcNum) AS with_paysplit,
    ROUND(100.0 * COUNT(DISTINCT ps.ProcNum) / COUNT(DISTINCT pl.ProcNum), 2) AS paysplit_pct,
    COUNT(DISTINCT adj.ProcNum) AS with_adjustment,
    ROUND(100.0 * COUNT(DISTINCT adj.ProcNum) / COUNT(DISTINCT pl.ProcNum), 2) AS adjustment_pct
FROM procedurelog pl
LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
LEFT JOIN adjustment adj ON pl.ProcNum = adj.ProcNum
WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01';


-- 2.3: Code Relationships
-- Purpose: Test procedure code relationships and frequency
SELECT 
    COUNT(pl.ProcNum) AS proc_count,
    pc.ProcCode,
    pc.Descript,
    ROUND(100.0 * COUNT(pl.ProcNum) / (SELECT COUNT(*) FROM procedurelog 
                                       WHERE ProcDate >= '2024-01-01' AND ProcDate < '2025-01-01'), 2) AS percentage
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
GROUP BY pc.ProcCode, pc.Descript
ORDER BY proc_count DESC
LIMIT 20;

-- 2.4: Fee Distribution
-- Purpose: Analyze fee distribution
SELECT 
    CASE 
        WHEN ProcFee = 0 THEN 'Zero fee'
        WHEN ProcFee < 100 THEN 'Under $100'
        WHEN ProcFee < 250 THEN '$100-$249'
        WHEN ProcFee < 500 THEN '$250-$499'
        WHEN ProcFee < 1000 THEN '$500-$999'
        WHEN ProcFee < 2000 THEN '$1000-$1999'
        ELSE '$2000+' 
    END AS fee_range,
    COUNT(*) AS proc_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    MIN(ProcFee) AS min_fee,
    MAX(ProcFee) AS max_fee,
    AVG(ProcFee) AS avg_fee
FROM procedurelog
WHERE ProcDate >= '2024-01-01' AND ProcDate < '2025-01-01'
GROUP BY 
    CASE 
        WHEN ProcFee = 0 THEN 'Zero fee'
        WHEN ProcFee < 100 THEN 'Under $100'
        WHEN ProcFee < 250 THEN '$100-$249'
        WHEN ProcFee < 500 THEN '$250-$499'
        WHEN ProcFee < 1000 THEN '$500-$999'
        WHEN ProcFee < 2000 THEN '$1000-$1999'
        ELSE '$2000+' 
    END
ORDER BY min_fee;

-- =============================================
-- PHASE 3: ANALYTICAL CTEs TESTING
-- =============================================

-- 3.1: Payment Activity Testing
-- Purpose: Test PaymentActivity CTE with aggregated metrics
WITH PaymentActivity AS (
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
)
SELECT 
    COUNT(*) AS total_records,
    SUM(CASE WHEN total_paid > 0 THEN 1 ELSE 0 END) AS paid_procedures,
    ROUND(100.0 * SUM(CASE WHEN total_paid > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS paid_percentage,
    SUM(CASE WHEN insurance_paid > 0 THEN 1 ELSE 0 END) AS insurance_paid_count,
    SUM(CASE WHEN direct_paid > 0 THEN 1 ELSE 0 END) AS direct_paid_count,
    SUM(CASE WHEN adjustments != 0 THEN 1 ELSE 0 END) AS with_adjustments_count,
    AVG(total_paid) AS avg_total_paid,
    SUM(total_paid) AS total_payments
FROM PaymentActivity;

-- 3.2: Payment Split Pattern Testing
-- Purpose: Test PaymentSplitMetrics CTE with distribution analysis
WITH PaymentSplitMetrics AS (
    SELECT 
      ps.ProcNum,
      COUNT(*) AS split_count,
      CASE 
        WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
        WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
        ELSE 'review_needed'
      END AS split_pattern
    FROM paysplit ps
    JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum 
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
    GROUP BY ps.ProcNum
)
SELECT 
    split_pattern,
    COUNT(*) AS count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    MIN(split_count) AS min_splits,
    AVG(split_count) AS avg_splits,
    MAX(split_count) AS max_splits
FROM PaymentSplitMetrics
GROUP BY split_pattern;

-- 3.3: Status and Payment CrossTab
-- Purpose: Analyze payment statistics by procedure status
WITH PaymentActivity AS (
    SELECT 
      pl.ProcNum,
      pl.ProcStatus,
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
    GROUP BY pl.ProcNum, pl.ProcStatus, pl.ProcFee
)
SELECT 
    ProcStatus,
    COUNT(*) AS proc_count,
    SUM(CASE WHEN total_paid > 0 THEN 1 ELSE 0 END) AS paid_count,
    ROUND(100.0 * SUM(CASE WHEN total_paid > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS paid_pct,
    SUM(ProcFee) AS total_fees,
    SUM(total_paid) AS total_payments,
    ROUND(100.0 * SUM(total_paid) / NULLIF(SUM(ProcFee), 0), 2) AS payment_ratio,
    AVG(CASE WHEN ProcFee > 0 THEN total_paid / ProcFee ELSE NULL END) AS avg_payment_ratio
FROM PaymentActivity
GROUP BY ProcStatus
ORDER BY ProcStatus;

-- =============================================
-- PHASE 4: SUCCESS CRITERIA TESTING
-- =============================================

-- 4.1: Excluded Codes Validation
-- Purpose: Validate the excluded codes list
WITH ExcludedCodes AS (
    SELECT CodeNum, ProcCode, Descript
    FROM procedurecode 
    WHERE ProcCode IN (
      '~GRP~', 'D9987', 'D9986', 'Watch', 'Ztoth', 'D0350',
      '00040', 'D2919', '00051',
      'D9992', 'D9995', 'D9996',
      'D0190', 'D0171', 'D0140', 'D9430', 'D0120'
    )
)
SELECT 
    pc.ProcCode, 
    pc.Descript,
    COUNT(pl.ProcNum) AS proc_count
FROM ExcludedCodes ec
JOIN procedurecode pc ON ec.CodeNum = pc.CodeNum
LEFT JOIN procedurelog pl ON pc.CodeNum = pl.CodeNum 
     AND pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
GROUP BY pc.ProcCode, pc.Descript;

-- 4.2: Threshold Testing
-- Purpose: Test success threshold criteria
WITH 
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
    SELECT 
      pl.ProcNum,
      pl.ProcFee,
      COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_paid,
      COALESCE(SUM(ps.SplitAmt), 0) AS direct_paid,
      COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
    GROUP BY pl.ProcNum, pl.ProcFee
),
ThresholdTests AS (
    SELECT 
      pl.ProcNum,
      pl.ProcStatus,
      pl.ProcFee,
      pl.CodeNum,
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
        THEN 1 ELSE 0 END AS target_journey_success
    FROM procedurelog pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
)
SELECT 
    ProcStatus,
    COUNT(*) AS proc_count,
    SUM(target_journey_success) AS successful,
    ROUND(100.0 * SUM(target_journey_success) / COUNT(*), 2) AS success_rate,
    SUM(CASE WHEN threshold_category = 'zero_fee' THEN 1 ELSE 0 END) AS zero_fee_count,
    SUM(CASE WHEN threshold_category = 'strict_98' THEN 1 ELSE 0 END) AS strict_98_count,
    SUM(CASE WHEN threshold_category = 'current_95' THEN 1 ELSE 0 END) AS current_95_count,
    SUM(CASE WHEN threshold_category = 'lenient_90' THEN 1 ELSE 0 END) AS lenient_90_count,
    SUM(CASE WHEN threshold_category = 'below_90' THEN 1 ELSE 0 END) AS below_90_count
FROM ThresholdTests
GROUP BY ProcStatus
ORDER BY ProcStatus;

-- 4.3: Multi-Threshold Comparison
-- Purpose: Compare different payment ratio thresholds
WITH 
PaymentActivity AS (
    SELECT 
      pl.ProcNum,
      pl.ProcFee,
      COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
    GROUP BY pl.ProcNum, pl.ProcFee
)
SELECT
    'ProcStatus = 2 (Completed)' AS filter_criteria,
    COUNT(*) AS total_procedures,
    SUM(CASE WHEN ProcFee = 0 THEN 1 ELSE 0 END) AS zero_fee_count,
    SUM(CASE WHEN ProcFee > 0 AND payment_ratio >= 1.00 THEN 1 ELSE 0 END) AS full_payment_count,
    SUM(CASE WHEN ProcFee > 0 AND payment_ratio >= 0.98 THEN 1 ELSE 0 END) AS above_98_pct_count,
    SUM(CASE WHEN ProcFee > 0 AND payment_ratio >= 0.95 THEN 1 ELSE 0 END) AS above_95_pct_count,
    SUM(CASE WHEN ProcFee > 0 AND payment_ratio >= 0.90 THEN 1 ELSE 0 END) AS above_90_pct_count,
    SUM(CASE WHEN ProcFee > 0 AND payment_ratio < 0.90 THEN 1 ELSE 0 END) AS below_90_pct_count,
    SUM(CASE WHEN ProcFee > 0 AND payment_ratio = 0 THEN 1 ELSE 0 END) AS zero_payment_count,
    ROUND(100.0 * SUM(CASE WHEN ProcFee > 0 AND payment_ratio >= 0.95 THEN 1 ELSE 0 END) / 
          SUM(CASE WHEN ProcFee > 0 THEN 1 ELSE 0 END), 2) AS pct_above_95_threshold
FROM (
    SELECT 
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcFee,
        COALESCE(pa.total_paid, 0) AS total_paid,
        CASE WHEN pl.ProcFee > 0 THEN COALESCE(pa.total_paid, 0) / pl.ProcFee ELSE NULL END AS payment_ratio
    FROM procedurelog pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
    AND pl.ProcStatus = 2
) payment_data;

-- 4.4: Zero-Fee Analysis
-- Purpose: Analyze zero-fee procedures in detail
WITH 
ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
      '~GRP~', 'D9987', 'D9986', 'Watch', 'Ztoth', 'D0350',
      '00040', 'D2919', '00051',
      'D9992', 'D9995', 'D9996',
      'D0190', 'D0171', 'D0140', 'D9430', 'D0120'
    )
)
SELECT 
    CASE 
        WHEN pl.CodeNum IN (SELECT CodeNum FROM ExcludedCodes) THEN 'Excluded'
        ELSE 'Standard'
    END AS zero_fee_type,
    pl.ProcStatus,
    COUNT(*) AS proc_count,
    COUNT(DISTINCT pc.ProcCode) AS unique_codes
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
AND pl.ProcFee = 0
GROUP BY 
    CASE 
        WHEN pl.CodeNum IN (SELECT CodeNum FROM ExcludedCodes) THEN 'Excluded'
        ELSE 'Standard'
    END,
    pl.ProcStatus
ORDER BY zero_fee_type, pl.ProcStatus;

-- =============================================
-- PHASE 5: COMPLEX ANALYSIS
-- =============================================

-- 5.1: Edge Case Identification
-- Purpose: Identify unusual payment patterns for investigation
WITH 
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
    SELECT 
      pl.ProcNum,
      pl.ProcFee,
      COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_paid,
      COALESCE(SUM(ps.SplitAmt), 0) AS direct_paid,
      COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
    GROUP BY pl.ProcNum, pl.ProcFee
),
ThresholdTests AS (
    SELECT 
      pl.ProcNum,
      pl.ProcStatus,
      pl.ProcFee,
      COALESCE(pa.total_paid, 0) AS total_paid,
      COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) AS payment_ratio,
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
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
),
EdgeCases AS (
    SELECT 
      pl.ProcNum,
      pl.PatNum,
      pl.ProcDate,
      pc.ProcCode,
      pc.Descript,
      pl.ProcStatus,
      pl.ProcFee,
      tt.total_paid,
      tt.payment_ratio,
      tt.target_journey_success,
      CASE 
        WHEN tt.payment_ratio >= 0.95 AND tt.target_journey_success = 0 THEN 'High_ratio_failure'
        WHEN tt.payment_ratio < 0.95 AND tt.target_journey_success = 1 THEN 'Low_ratio_success'
        WHEN pl.ProcFee = 0 AND tt.total_paid > 0 THEN 'Zero_fee_payment'
        WHEN pl.ProcFee > 0 AND tt.total_paid > pl.ProcFee THEN 'Overpayment'
        ELSE 'Normal'
      END AS edge_case_type
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    JOIN ThresholdTests tt ON pl.ProcNum = tt.ProcNum
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
)
SELECT 
    edge_case_type,
    COUNT(*) AS case_count,
