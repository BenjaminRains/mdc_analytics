/*
 * Payment and Split Validation Query
 * 
 * Purpose: Analyze payment records and their splits for validation and anomaly detection
 * Time period: 2024 calendar year
 * 
 * Queries and Output Files:
 * 1. payment_split_validation_2024_summary.csv
 *    - From: SELECT * FROM (... UNION ALL ...) combined_results
 *    - Overall payment statistics and patterns
 *    - Payment method distributions
 *    - Split patterns and timing
 * 
 * 2. payment_split_validation_2024_base_counts.csv
 *    - From: SELECT 'Payment Counts' as metric...
 *    - Base payment and split counts
 *    - Overall payment statistics
 *    - Split count verification
 * 
 * 3. payment_split_validation_2024_source_counts.csv
 *    - From: SELECT CASE WHEN cp.InsPayAmt...
 *    - Insurance vs Patient payment counts
 *    - Split patterns by payment source
 *    - Source-specific metrics
 * 
 * 4. payment_split_validation_2024_filter_summary.csv
 *    - From: SELECT 'filter_summary' as report_type...
 *    - Filter reason breakdown
 *    - Payment counts and amounts by category
 * 
 * 5. payment_split_validation_2024_diagnostic.csv
 *    - From: SELECT 'diagnostic_summary' as report_type...
 *    - Detailed diagnostic metrics by filter
 *    - Average splits, min/max amounts
 * 
 * 6. payment_split_validation_2024_verification.csv
 *    - From: SELECT 'verification_counts' as report_type...
 *    - Base counts and join verification
 *    - Payment tracking through stages
 * 
 * 7. payment_split_validation_2024_problems.csv
 *    - From: SELECT 'problem_details' as report_type...
 *    - Detailed problem payment records
 *    - Top 100 issues by amount
 * 
 * 8. payment_split_validation_2024_duplicate_joins.csv
 *    - From: SELECT p.PayNum, COUNT(*) as join_count...
 *    - Identifies duplicate payments from joins
 *    - Split and ClaimProc counts per payment
 * 
 * 9. payment_split_validation_2024_join_stages.csv
 *    - From: WITH PaymentCounts AS...
 *    - Tracks payment counts through join stages
 *    - Identifies missing or duplicate payments
 *    - Validates join integrity
 * 
 * Common Metrics (23 columns):
 * - total_payments: Count/PayNum
 * - avg_splits_per_payment: Average splits/PayAmt
 * - payments_with_split_mismatch: Mismatch count/split_count
 * - payment_method_count: Distinct methods
 * - total_reversals: Negative payment count
 * - insurance_payments: Insurance payment count
 * - patient_payments: Patient payment count
 * - normal_split_count: 1-3 splits
 * - complex_split_count: 4-15 splits
 * - review_needed_count: >15 splits
 * - avg_days_to_payment: Payment timing
 * - payment patterns: Split sequences
 * - split_difference: Amount discrepancies
 * - split_count: Total splits
 */

WITH PaymentSummary AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        p.PayNote,
        COUNT(ps.SplitNum) AS split_count,
        SUM(ps.SplitAmt) AS total_split_amount,
        ABS(p.PayAmt - SUM(ps.SplitAmt)) AS split_difference,
        CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
),
PaymentMethodAnalysis AS (
    SELECT 
        p.PayType,
        COUNT(*) AS payment_count,
        SUM(p.PayAmt) AS total_amount,
        COUNT(CASE WHEN p.PayAmt < 0 THEN 1 END) AS reversal_count,
        AVG(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS error_rate
    FROM payment p
    JOIN PaymentSummary ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayType
),
InsurancePaymentAnalysis AS (
    SELECT 
        CASE 
            WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
            ELSE 'Patient'
        END AS payment_source,
        COUNT(DISTINCT ps.PayNum) AS payment_count,
        SUM(ps.SplitAmt) AS total_paid,
        AVG(DATEDIFF(p.PayDate, pl.ProcDate)) AS avg_days_to_payment
    FROM paysplit ps
    JOIN payment p ON ps.PayNum = p.PayNum
    JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
    LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY 
        CASE 
            WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
            ELSE 'Patient'
        END
),
ProcedurePayments AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        pl.ProcStatus,
        pl.CodeNum,
        ps.PayNum,
        ps.SplitAmt,
        p.PayAmt,
        p.PayDate,
        ps.UnearnedType,
        DATEDIFF(p.PayDate, pl.ProcDate) AS days_to_payment,
        ROW_NUMBER() OVER (PARTITION BY pl.ProcNum ORDER BY p.PayDate) AS payment_sequence
    FROM procedurelog pl
    JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
),
SplitPatternAnalysis AS (
    SELECT 
        ProcNum,
        COUNT(DISTINCT PayNum) AS payment_count,
        COUNT(*) AS split_count,
        SUM(SplitAmt) AS total_paid,
        AVG(days_to_payment) AS avg_days_to_payment,
        GROUP_CONCAT(payment_sequence ORDER BY payment_sequence) AS payment_sequence_pattern,
        CASE 
            WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
            WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
            WHEN COUNT(*) > 15 THEN 'review_needed'
            ELSE 'no_splits'
        END AS split_pattern
    FROM ProcedurePayments
    GROUP BY ProcNum
),
PaymentBaseCounts AS (
    -- Get raw payment counts before any filtering
    SELECT 
        'base_counts' as metric,
        COUNT(DISTINCT p.PayNum) as total_payments,
        MIN(p.PayDate) as min_date,
        MAX(p.PayDate) as max_date
    FROM payment p
    WHERE p.PayDate >= '2024-01-01'
        AND p.PayDate < '2025-01-01'
),
PaymentJoinDiagnostics AS (
    -- Track payments through each join
    SELECT 
        p.PayNum,
        p.PayDate,
        p.PayAmt,
        p.PayType,
        CASE 
            WHEN ps.PayNum IS NULL THEN 'No Splits'
            WHEN cp.ProcNum IS NULL THEN 'No Procedures'
            WHEN cp.InsPayAmt IS NULL THEN 'No Insurance'
            ELSE 'Complete'
        END as join_status,
        COUNT(DISTINCT ps.SplitNum) as split_count,
        COUNT(DISTINCT cp.ProcNum) as proc_count
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    WHERE p.PayDate >= '2024-01-01'
        AND p.PayDate < '2025-01-01'
    GROUP BY 
        p.PayNum,
        p.PayDate,
        p.PayAmt,
        p.PayType,
        CASE 
            WHEN ps.PayNum IS NULL THEN 'No Splits'
            WHEN cp.ProcNum IS NULL THEN 'No Procedures'
            WHEN cp.InsPayAmt IS NULL THEN 'No Insurance'
            ELSE 'Complete'
        END
),
PaymentFilterDiagnostics AS (
    -- Track which filters are affecting payments
    SELECT 
        pd.PayNum,
        pd.PayAmt,
        pd.join_status,
        pd.split_count,
        pd.proc_count,
        CASE
            WHEN pd.PayAmt = 0 THEN 'Zero Amount'
            WHEN pd.split_count > 15 THEN 'High Split Count'
            WHEN pd.PayAmt < 0 THEN 'Reversal'
            WHEN pd.join_status != 'Complete' THEN pd.join_status
            ELSE 'Normal Payment'
        END as filter_reason
    FROM PaymentJoinDiagnostics pd
)

-- 1. Main Analysis Output
SELECT * FROM (
    -- Summary Branch
    SELECT 
        'summary' AS report_type,
        pb.total_payments AS base_payment_count,
        COUNT(DISTINCT pfd.PayNum) AS filtered_payment_count,
        AVG(pfd.split_count) AS avg_splits_per_payment,
        SUM(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS payments_with_split_mismatch,
        COUNT(DISTINCT pma.PayType) AS payment_method_count,
        MAX(pma.reversal_count) AS total_reversals,
        SUM(CASE WHEN ipa.payment_source = 'Insurance' THEN ipa.payment_count ELSE 0 END) AS insurance_payments,
        SUM(CASE WHEN ipa.payment_source = 'Patient' THEN ipa.payment_count ELSE 0 END) AS patient_payments,
        COUNT(CASE WHEN spa.split_pattern = 'normal_split' THEN 1 END) AS normal_split_count,
        COUNT(CASE WHEN spa.split_pattern = 'complex_split' THEN 1 END) AS complex_split_count,
        COUNT(CASE WHEN spa.split_pattern = 'review_needed' THEN 1 END) AS review_needed_count,
        AVG(spa.avg_days_to_payment) AS avg_days_to_payment,
        MAX(spa.payment_count) AS max_payments_per_procedure,
        AVG(spa.payment_count) AS avg_payments_per_procedure,
        GROUP_CONCAT(DISTINCT CASE WHEN spa.split_count > 3 THEN spa.payment_sequence_pattern END) AS complex_payment_patterns,
        AVG(pp.ProcFee) AS avg_procedure_fee,
        AVG(spa.total_paid) AS avg_total_paid,
        COUNT(CASE WHEN spa.total_paid > pp.ProcFee THEN 1 ELSE 0 END) AS overpayment_count,
        COUNT(CASE WHEN pp.UnearnedType = 0 THEN 1 ELSE 0 END) AS regular_payment_count,
        COUNT(CASE WHEN pp.UnearnedType = 288 THEN 1 ELSE 0 END) AS prepayment_count,
        COUNT(CASE WHEN pp.UnearnedType = 439 THEN 1 ELSE 0 END) AS tp_prepayment_count,
        SUM(CASE WHEN pfd.filter_reason != 'Normal Payment' THEN 1 ELSE 0 END) AS problem_payment_count
    FROM PaymentFilterDiagnostics pfd
    CROSS JOIN PaymentBaseCounts pb
    LEFT JOIN PaymentSummary ps ON pfd.PayNum = ps.PayNum
    LEFT JOIN ProcedurePayments pp ON pfd.PayNum = pp.PayNum
    LEFT JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
    LEFT JOIN PaymentMethodAnalysis pma ON ps.PayType = pma.PayType
    LEFT JOIN InsurancePaymentAnalysis ipa ON 1=1
    GROUP BY pb.total_payments

    UNION ALL

    -- Problem Detail Branch
    SELECT 
        'problem_detail' AS report_type,
        CAST(pfd.PayNum AS CHAR) AS base_payment_count,
        pfd.PayAmt AS filtered_payment_count,
        pfd.split_count AS avg_splits_per_payment,
        pfd.split_count AS payments_with_split_mismatch,
        NULL AS payment_method_count,
        NULL AS total_reversals,
        NULL AS insurance_payments,
        NULL AS patient_payments,
        pfd.split_count AS normal_split_count,
        pfd.split_count AS complex_split_count,
        CAST(pp.ProcNum AS CHAR) AS review_needed_count,
        pp.days_to_payment AS avg_days_to_payment,
        spa.payment_count AS max_payments_per_procedure,
        spa.payment_count AS avg_payments_per_procedure,
        spa.payment_sequence_pattern AS complex_payment_patterns,
        pp.ProcFee AS avg_procedure_fee,
        spa.total_paid AS avg_total_paid,
        CASE WHEN spa.total_paid > pp.ProcFee THEN 1 ELSE 0 END AS overpayment_count,
        CASE WHEN pp.UnearnedType = 0 THEN 1 ELSE 0 END AS regular_payment_count,
        0 AS prepayment_count,
        0 AS tp_prepayment_count,
        pfd.split_count AS missing_proc_count
    FROM PaymentFilterDiagnostics pfd
    JOIN ProcedurePayments pp ON pfd.PayNum = pp.PayNum
    JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
    WHERE pfd.filter_reason != 'Normal Payment'
) combined_results
ORDER BY report_type DESC;

-- 2. Payment and Split Counts base
SELECT 
    'Payment Counts' as metric,
    COUNT(DISTINCT p.PayNum) as total_payments,
    COUNT(DISTINCT ps.SplitNum) as total_splits,
    COUNT(DISTINCT ps.ProcNum) as total_procedures,
    CAST(COUNT(DISTINCT ps.SplitNum) AS FLOAT) / 
        NULLIF(COUNT(DISTINCT p.PayNum), 0) as avg_splits_per_payment
FROM payment p
LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
WHERE p.PayDate >= '2024-01-01'
    AND p.PayDate < '2025-01-01';

-- 3. Insurance vs Patient payment counts
SELECT 
    CASE 
        WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
        ELSE 'Patient'
    END AS metric,
    COUNT(DISTINCT ps.PayNum) as total_payments,
    COUNT(DISTINCT ps.SplitNum) as total_splits,
    COUNT(DISTINCT ps.ProcNum) as total_procedures,
    CAST(COUNT(DISTINCT ps.SplitNum) AS FLOAT) / 
        NULLIF(COUNT(DISTINCT ps.PayNum), 0) as avg_splits_per_payment
FROM paysplit ps
JOIN payment p ON ps.PayNum = p.PayNum
LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
WHERE p.PayDate >= '2024-01-01'
    AND p.PayDate < '2025-01-01'
GROUP BY 
    CASE 
        WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
        ELSE 'Patient'
    END;

-- 4. Filter Summary report using PaymentFilterDiagnostics
SELECT 
    'filter_summary' as report_type,
    filter_reason,
    COUNT(*) as payment_count,
    SUM(PayAmt) as total_amount
FROM PaymentFilterDiagnostics
GROUP BY filter_reason
ORDER BY payment_count DESC;

-- 5. Diagnostic summary report
SELECT 
    'diagnostic_summary' as report_type,
    filter_reason,
    COUNT(*) as payment_count,
    SUM(PayAmt) as total_amount,
    AVG(split_count) as avg_splits,
    MIN(PayAmt) as min_amount,
    MAX(PayAmt) as max_amount
FROM PaymentFilterDiagnostics
GROUP BY filter_reason
ORDER BY payment_count DESC;

-- 6. Verfication counts report
SELECT 
    'verification_counts' as report_type,
    'Total Base Payments' as metric,
    total_payments as payment_count,
    min_date,
    max_date
FROM PaymentBaseCounts

UNION ALL

SELECT 
    'verification_counts' as report_type,
    join_status as metric,
    COUNT(*) as payment_count,
    MIN(PayDate) as min_date,
    MAX(PayDate) as max_date
FROM PaymentJoinDiagnostics
GROUP BY join_status;

-- 7. Detailed problem payments for investigation
SELECT 
    'problem_details' as report_type,
    pd.*
FROM PaymentFilterDiagnostics pd
WHERE filter_reason != 'Normal Payment'
ORDER BY PayAmt DESC
LIMIT 100;

-- 8. Check for duplicate payments in joins
SELECT 
    p.PayNum,
    p.PayAmt,
    p.PayDate,
    COUNT(*) as join_count,
    COUNT(DISTINCT ps.SplitNum) as split_count,
    COUNT(DISTINCT cp.ClaimProcNum) as claimproc_count,
    GROUP_CONCAT(DISTINCT cp.ClaimNum) as claim_nums
FROM payment p
LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
-- Join to claim first to get the correct relationship
LEFT JOIN claim c ON ps.ClaimNum = c.ClaimNum
LEFT JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum 
    AND cp.ProcNum = ps.ProcNum  -- Ensure procedure matches
    AND cp.Status IN (1, 4, 5)   -- Only completed/received claims
    AND cp.InsPayAmt > 0         -- Only actual insurance payments
WHERE p.PayDate >= '2024-01-01' 
    AND p.PayDate < '2025-01-01'
GROUP BY p.PayNum, p.PayAmt, p.PayDate
HAVING COUNT(*) > 1;

-- 9. Compare payment counts at each join stage
SELECT 
    (SELECT COUNT(DISTINCT PayNum) 
     FROM payment 
     WHERE PayDate >= '2024-01-01' AND PayDate < '2025-01-01'
    ) as base_count,
    
    (SELECT COUNT(DISTINCT p.PayNum)
     FROM payment p
     LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
     WHERE p.PayDate >= '2024-01-01' AND p.PayDate < '2025-01-01'
    ) as paysplit_count,
    
    (SELECT COUNT(DISTINCT p.PayNum)
     FROM payment p
     LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
     LEFT JOIN claim c ON ps.ClaimNum = c.ClaimNum
     LEFT JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum 
         AND cp.ProcNum = ps.ProcNum
         AND cp.Status IN (1, 4, 5)
         AND cp.InsPayAmt > 0
     WHERE p.PayDate >= '2024-01-01' AND p.PayDate < '2025-01-01'
    ) as claimproc_count,
    
    (SELECT COUNT(DISTINCT PayNum) 
     FROM payment 
     WHERE PayDate >= '2024-01-01' AND PayDate < '2025-01-01'
    ) - 
    (SELECT COUNT(DISTINCT p.PayNum)
     FROM payment p
     LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
     LEFT JOIN claim c ON ps.ClaimNum = c.ClaimNum
     LEFT JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum 
         AND cp.ProcNum = ps.ProcNum
         AND cp.Status IN (1, 4, 5)
         AND cp.InsPayAmt > 0
     WHERE p.PayDate >= '2024-01-01' AND p.PayDate < '2025-01-01'
    ) as missing_payments;
