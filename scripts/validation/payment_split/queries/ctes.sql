/*
===============================================================================
Payment Split Validation CTEs
===============================================================================
Purpose:
  This file defines common table expressions (CTEs) used for payment split 
  validation queries. These CTEs extract and compute metrics related to 
  payment splits, procedures, and insurance relationships. They are intended 
  to be loaded by an export script that appends them to each query before 
  execution.

Usage:
  Include the contents of this file at the start of any query that requires these
  common expressions. The export script automatically loads this file and adds its 
  contents to each query configuration before exporting the results.

CTE Dependency Order:
  1. BasePayments: Pre-filter base payments by date.
  2. BaseSplits: Pre-aggregate split details for base payments.
  3. PaymentSummary: Compute basic payment metrics and flags.
  4. PaymentMethodAnalysis: Detailed analysis by payment type.
  5. PaymentSourceCategories: Categorize payments by source.
  6. PaymentSourceSummary: Summarize payment counts and amounts by source.
  7. TotalPayments: Calculate total payment counts and amounts across all sources.
  8. InsurancePaymentAnalysis: Compute insurance-specific metrics.
  9. ProcedurePayments: Extract procedure-level payment details.
 10. SplitPatternAnalysis: Analyze and categorize payment split patterns.
 11. PaymentBaseCounts: Compute overall payment volume metrics.
 12. PaymentJoinDiagnostics: Validate relationships between payments, splits, and procedures.
 13. PaymentFilterDiagnostics: Categorize and filter payments based on diagnostics.
 14. JoinStageCounts: Analyze payment progression through join stages.
 15. SuspiciousSplitAnalysis: Identify suspicious or abnormal split patterns.
 16. PaymentDetailsBase: Base payment and split information for detailed analysis.
 17. PaymentDetailsMetrics: Compute detailed metrics per payment.
 18. PaymentDailyDetails: Extract daily payment patterns and metrics.
 19. FilterStats: Compute summary statistics for each payment filter category.
 20. ProblemPayments: Pre-filter payments flagged as problematic.
 21. ClaimMetrics: Analyze claim relationships for payment split analysis.
 22. ProblemClaimDetails: Detailed analysis of known problematic claims.
===============================================================================
*/

WITH 
-- 1. BasePayments: Pre-filter base payments based on the defined date range.
BasePayments AS (
    SELECT PayNum, PayDate, PayAmt, PayType
    FROM payment 
    WHERE PayDate >= '2024-01-01' AND PayDate < '2025-01-01'
),

-- 2. BaseSplits: Pre-aggregate split details for base payments.
BaseSplits AS (
    SELECT 
        ps.PayNum,
        COUNT(DISTINCT ps.SplitNum) AS split_count,
        COUNT(DISTINCT ps.ProcNum) AS proc_count,
        SUM(ps.SplitAmt) AS total_split_amount
    FROM paysplit ps
    JOIN BasePayments p ON ps.PayNum = p.PayNum
    GROUP BY ps.PayNum
),

-- 3. PaymentSummary: Compute basic payment metrics and categorize payments.
PaymentSummary AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        p.PayNote,
        COUNT(ps.SplitNum) AS split_count,
        SUM(ps.SplitAmt) AS total_split_amount,
        ABS(p.PayAmt - COALESCE(SUM(ps.SplitAmt), 0)) AS split_difference,
        CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal,
        CASE WHEN COUNT(ps.SplitNum) > 15 THEN 1 ELSE 0 END AS is_high_split,
        CASE WHEN p.PayAmt = 0 THEN 1 ELSE 0 END AS is_zero_amount,
        CASE WHEN p.PayAmt > 5000 THEN 1 ELSE 0 END AS is_large_payment,
        CASE WHEN COUNT(ps.SplitNum) = 1 THEN 1 ELSE 0 END AS is_single_split,
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'
            WHEN p.PayType IN (69, 70, 71) THEN 'Check/Cash'
            WHEN p.PayType IN (391, 412) THEN 'Card/Online'
            WHEN p.PayType = 72 THEN 'Refund'
            WHEN p.PayType = 0 THEN 'Transfer'
            ELSE 'Other'
        END AS payment_category
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
),

-- 4. PaymentMethodAnalysis: Detailed analysis by payment type.
PaymentMethodAnalysis AS (
    SELECT 
        p.PayType,
        COUNT(*) AS payment_count,
        SUM(p.PayAmt) AS total_amount,
        COUNT(CASE WHEN p.PayAmt < 0 THEN 1 END) AS reversal_count,
        AVG(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS error_rate,
        MIN(p.PayAmt) AS min_amount,
        MAX(p.PayAmt) AS max_amount,
        COUNT(CASE WHEN p.PayAmt = 0 THEN 1 END) AS zero_count,
        ps.payment_category
    FROM payment p
    JOIN PaymentSummary ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayType, ps.payment_category
),

-- 5. PaymentSourceCategories: Categorize payments by their source (Insurance, Transfer, Refund, or Patient).
PaymentSourceCategories AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'
            WHEN p.PayType = 0 THEN 'Transfer'
            WHEN p.PayType = 72 THEN 'Refund'
            WHEN EXISTS (
                SELECT 1 
                FROM paysplit ps2
                JOIN claimproc cp2 ON ps2.ProcNum = cp2.ProcNum
                WHERE ps2.PayNum = p.PayNum 
                  AND cp2.Status IN (1, 2, 4, 6)
            ) THEN 'Insurance'
            ELSE 'Patient'
        END as payment_source
    FROM payment p
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
),

-- 6. PaymentSourceSummary: Summarize payment counts and amounts by payment source.
PaymentSourceSummary AS (
    SELECT 
        pc.payment_source,
        COUNT(*) AS payment_count,
        SUM(pc.PayAmt) AS total_paid,
        MIN(pc.PayDate) AS min_date,
        MAX(pc.PayDate) AS max_date,
        AVG(pc.PayAmt) AS avg_payment
    FROM PaymentSourceCategories pc
    GROUP BY pc.payment_source
),

-- 7. TotalPayments: Calculate total payment counts and amounts across all sources.
TotalPayments AS (
    SELECT 
        SUM(payment_count) as total_count,
        SUM(total_paid) as total_amount
    FROM PaymentSourceSummary
),

-- 8. InsurancePaymentAnalysis: Compute metrics specific to insurance payments.
InsurancePaymentAnalysis AS (
    SELECT 
        pss.payment_source,
        pss.payment_count,
        pss.total_paid,
        pss.avg_payment,
        COUNT(DISTINCT cp.PlanNum) AS plan_count,
        COUNT(DISTINCT cp.ClaimNum) AS claim_count,
        COUNT(DISTINCT CASE WHEN p.PayType IN (417, 574, 634) THEN p.PayNum END) AS direct_ins_count,
        COUNT(DISTINCT CASE WHEN p.PayType IN (69, 70, 71) THEN p.PayNum END) AS check_cash_count,
        COUNT(DISTINCT CASE WHEN p.PayType IN (391, 412) THEN p.PayNum END) AS card_count,
        AVG(CASE 
            WHEN pl.ProcDate IS NOT NULL THEN DATEDIFF(p.PayDate, pl.ProcDate)
            ELSE NULL 
        END) AS avg_days_to_payment
    FROM PaymentSourceCategories psc
    JOIN payment p ON psc.PayNum = p.PayNum
    JOIN PaymentSourceSummary pss ON psc.payment_source = pss.payment_source
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    LEFT JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
    LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
         AND cp.Status IN (1, 2, 4, 6)
    GROUP BY 
        pss.payment_source,
        pss.payment_count,
        pss.total_paid,
        pss.avg_payment
),

-- 9. ProcedurePayments: Extract procedure-level payment details.
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
        pl.ProcDate,
        ps.UnearnedType,
        DATEDIFF(p.PayDate, pl.ProcDate) AS days_to_payment,
        ROW_NUMBER() OVER (PARTITION BY pl.ProcNum ORDER BY p.PayDate) AS payment_sequence,
        CASE 
            WHEN pl.ProcStatus = 1 THEN 'Complete'
            WHEN pl.ProcStatus = 2 THEN 'Existing'
            ELSE 'Other'
        END AS proc_status_desc,
        CASE WHEN ps.UnearnedType = 439 THEN 1 ELSE 0 END as is_prepayment,
        CASE WHEN DATEDIFF(p.PayDate, pl.ProcDate) < 0 THEN 1 ELSE 0 END as is_advance_payment,
        CASE 
            WHEN pl.ProcStatus = 1 AND pl.ProcFee > 1000 THEN 'major'
            WHEN pl.ProcStatus = 1 THEN 'minor'
            WHEN pl.ProcStatus = 2 THEN 'existing'
            ELSE 'other'
        END as procedure_category
    FROM procedurelog pl
    JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
),

-- 10. SplitPatternAnalysis: Analyze and categorize payment split patterns.
SplitPatternAnalysis AS (
    SELECT 
        ProcNum,
        COUNT(DISTINCT PayNum) AS payment_count,
        COUNT(*) AS split_count,
        SUM(SplitAmt) AS total_paid,
        AVG(days_to_payment) AS avg_days_to_payment,
        CASE 
            WHEN COUNT(*) = 1 THEN 'single_payment'
            WHEN COUNT(*) = 2 THEN 'double_payment'
            WHEN COUNT(*) BETWEEN 3 AND 5 THEN 'multiple_payment'
            WHEN COUNT(*) BETWEEN 6 AND 15 THEN 'complex_payment'
            ELSE 'review_needed'
        END AS split_pattern,
        MIN(days_to_payment) AS first_payment_days,
        MAX(days_to_payment) AS last_payment_days,
        DATEDIFF(MAX(PayDate), MIN(PayDate)) AS payment_span_days,
        MIN(SplitAmt) AS min_split_amount,
        MAX(SplitAmt) AS max_split_amount,
        CASE WHEN COUNT(*) > COUNT(DISTINCT PayNum) * 2 THEN 1 ELSE 0 END AS has_multiple_splits_per_payment,
        CASE WHEN MAX(days_to_payment) - MIN(days_to_payment) > 365 THEN 1 ELSE 0 END AS is_long_term_payment
    FROM ProcedurePayments
    GROUP BY ProcNum
),

-- 11. PaymentBaseCounts: Compute overall payment volume metrics.
PaymentBaseCounts AS (
    SELECT 
        'base_counts' as metric,
        COUNT(DISTINCT p.PayNum) as total_payments,
        (SELECT COUNT(*) FROM paysplit ps2 
         JOIN payment p2 ON ps2.PayNum = p2.PayNum 
         WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') as total_splits,
        (SELECT COUNT(DISTINCT pl2.ProcNum) 
         FROM procedurelog pl2 
         JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
         JOIN payment p2 ON ps2.PayNum = p2.PayNum
         WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') as total_procedures,
        SUM(p.PayAmt) as total_amount,
        AVG(p.PayAmt) as avg_payment,
        COUNT(CASE WHEN p.PayAmt < 0 THEN 1 END) as negative_payments,
        COUNT(CASE WHEN p.PayAmt = 0 THEN 1 END) as zero_payments,
        MIN(p.PayDate) as min_date,
        MAX(p.PayDate) as max_date,
        CAST((SELECT COUNT(*) FROM paysplit ps2 
              JOIN payment p2 ON ps2.PayNum = p2.PayNum 
              WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') AS FLOAT) / 
            COUNT(DISTINCT p.PayNum) as avg_splits_per_payment,
        CAST((SELECT COUNT(DISTINCT pl2.ProcNum) 
              FROM procedurelog pl2 
              JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
              JOIN payment p2 ON ps2.PayNum = p2.PayNum
              WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') AS FLOAT) / 
            COUNT(DISTINCT p.PayNum) as avg_procedures_per_payment
    FROM payment p
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY 'base_counts'
),

-- 12. PaymentJoinDiagnostics: Validate relationships between payments, splits, and procedures.
PaymentJoinDiagnostics AS (
    SELECT 
        p.PayNum,
        p.PayDate,
        p.PayAmt,
        p.PayType,
        CASE 
            WHEN NOT EXISTS (SELECT 1 FROM paysplit ps2 WHERE ps2.PayNum = p.PayNum) 
                THEN 'No Splits'
            WHEN NOT EXISTS (SELECT 1 FROM paysplit ps2 
                           JOIN procedurelog pl2 ON ps2.ProcNum = pl2.ProcNum 
                           WHERE ps2.PayNum = p.PayNum) 
                THEN 'No Procedures'
            WHEN NOT EXISTS (SELECT 1 FROM paysplit ps2 
                           JOIN claimproc cp2 ON ps2.ProcNum = cp2.ProcNum 
                           WHERE ps2.PayNum = p.PayNum AND cp2.InsPayAmt IS NOT NULL) 
                THEN 'No Insurance'
            ELSE 'Complete'
        END as join_status,
        COUNT(DISTINCT ps.SplitNum) as split_count,
        COUNT(DISTINCT pl.ProcNum) as proc_count
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    LEFT JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayNum, p.PayDate, p.PayAmt, p.PayType
),

-- 13. PaymentFilterDiagnostics: Categorize and filter payments based on diagnostics.
PaymentFilterDiagnostics AS (
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
            WHEN pd.join_status = 'No Insurance' THEN 'No Insurance'
            WHEN pd.join_status = 'No Procedures' THEN 'No Procedures'
            ELSE 'Normal Payment'
        END as filter_reason,
        CASE WHEN pd.split_count > pd.proc_count * 2 THEN 1 ELSE 0 END as has_multiple_splits_per_proc,
        CASE WHEN pd.PayAmt > 5000 THEN 1 ELSE 0 END as is_large_payment,
        CASE WHEN pd.split_count = 1 AND pd.proc_count = 1 THEN 1 ELSE 0 END as is_simple_payment,
        CASE 
            WHEN split_count > 0 AND proc_count > 0 
                 AND (split_count::float / proc_count) > 10 
            THEN 1 ELSE 0 
        END as has_high_split_ratio,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM paysplit ps2 
                JOIN claimproc cp2 ON ps2.ProcNum = cp2.ProcNum
                WHERE ps2.PayNum = pd.PayNum
                GROUP BY cp2.ClaimNum
                HAVING COUNT(*) > 1000
            ) THEN 1 ELSE 0 
        END as has_oversplit_claims
    FROM PaymentJoinDiagnostics pd
),

-- 14. JoinStageCounts: Analyze payment progression through join stages and related metrics.
JoinStageCounts AS (
    SELECT 
        pbc.total_payments as base_count,
        COUNT(DISTINCT CASE WHEN pjd.join_status != 'No Splits' THEN pjd.PayNum END) as with_splits,
        COUNT(DISTINCT CASE WHEN pjd.join_status NOT IN ('No Splits', 'No Procedures') THEN pjd.PayNum END) as with_procedures,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'Complete' THEN pjd.PayNum END) as with_insurance,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Insurance' AND pjd.PayAmt > 0 THEN pjd.PayNum END) as patient_payments,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt = 0 THEN pjd.PayNum END) as transfer_count,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt < 0 THEN pjd.PayNum END) as refund_count,
        AVG(ps.split_count) as avg_splits_per_payment,
        COUNT(DISTINCT CASE WHEN ps.split_difference > 0.01 THEN ps.PayNum END) as mismatch_count,
        COUNT(DISTINCT CASE WHEN pjd.split_count > 15 THEN pjd.PayNum END) as high_split_count,
        COUNT(DISTINCT CASE WHEN pjd.split_count = 1 THEN pjd.PayNum END) as single_split_count,
        COUNT(DISTINCT CASE WHEN pjd.PayAmt > 5000 THEN pjd.PayNum END) as large_payment_count
    FROM PaymentBaseCounts pbc
    CROSS JOIN PaymentJoinDiagnostics pjd
    LEFT JOIN PaymentSummary ps ON pjd.PayNum = ps.PayNum
    GROUP BY pbc.total_payments
),

-- 15. SuspiciousSplitAnalysis: Identify suspicious or abnormal split patterns.
SuspiciousSplitAnalysis AS (
    SELECT 
        ps.SplitNum as PaySplitNum,
        ps.PayNum,
        ps.ProcNum,
        cp.ClaimNum,
        ps.SplitAmt,
        p.PayDate,
        p.PayNote,
        COUNT(*) OVER (PARTITION BY cp.ClaimNum) as splits_per_claim,
        COUNT(*) OVER (PARTITION BY ps.PayNum) as splits_per_payment,
        MIN(ps.SplitAmt) OVER (PARTITION BY ps.PayNum) as min_split_amt,
        MAX(ps.SplitAmt) OVER (PARTITION BY ps.PayNum) as max_split_amt,
        CASE 
            WHEN COUNT(*) OVER (PARTITION BY cp.ClaimNum) > 1000 THEN 'High volume splits'
            WHEN ABS(MIN(ps.SplitAmt) OVER (PARTITION BY ps.PayNum)) = 
                 ABS(MAX(ps.SplitAmt) OVER (PARTITION BY ps.PayNum)) 
                THEN 'Symmetric splits'
            ELSE 'Normal pattern'
        END as split_pattern
    FROM paysplit ps
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE cp.ClaimNum IN (2536, 2542, 6519)
        AND p.PayDate BETWEEN '2024-10-30' AND '2024-11-05'
),

-- 16. PaymentDetailsBase: Base payment and split information for detailed analysis.
PaymentDetailsBase AS (
    SELECT 
        p.PayNum,
        p.PayDate,
        p.PayType,
        p.PayAmt,
        p.PayNote,
        ps.SplitNum,
        ps.SplitAmt,
        ps.ProcNum,
        cp.ClaimNum
    FROM payment p
    JOIN paysplit ps ON p.PayNum = ps.PayNum
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    JOIN claim c ON cp.ClaimNum = c.ClaimNum
    WHERE p.PayDate >= DATEADD(month, -1, CURRENT_TIMESTAMP)
),

-- 17. PaymentDetailsMetrics: Compute detailed metrics per payment.
PaymentDetailsMetrics AS (
    SELECT 
        PayNum,
        PayDate,
        PayType,
        PayAmt,
        PayNote,
        COUNT(SplitNum) as splits_in_payment,
        COUNT(DISTINCT ClaimNum) as claims_in_payment,
        COUNT(DISTINCT ProcNum) as procedures_in_payment,
        MIN(SplitAmt) as min_split,
        MAX(SplitAmt) as max_split,
        SUM(SplitAmt) as total_split_amount,
        ABS(PayAmt - SUM(SplitAmt)) as split_difference
    FROM PaymentDetailsBase
    GROUP BY PayNum, PayDate, PayType, PayAmt, PayNote
),

-- 18. PaymentDailyDetails: Extract daily payment patterns and metrics.
PaymentDailyDetails AS (
    SELECT 
        p.PayNum,
        p.PayDate,
        p.PayType,
        p.PayAmt,
        p.PayNote,
        ps.SplitNum,
        ps.SplitAmt,
        ps.ProcNum,
        cp.ClaimNum,
        cp.ClaimProcNum,
        cp.Status as ProcStatus,
        c.ClaimStatus,
        c.DateService
    FROM payment p
    JOIN paysplit ps ON p.PayNum = ps.PayNum
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    JOIN claim c ON cp.ClaimNum = c.ClaimNum
    WHERE p.PayDate >= DATEADD(month, -1, CURRENT_TIMESTAMP)
),

-- 19. FilterStats: Compute summary statistics for each payment filter category.
FilterStats AS (
    SELECT 
        filter_reason,
        COUNT(*) as payment_count,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as percentage,
        SUM(PayAmt) as total_amount,
        AVG(PayAmt) as avg_amount,
        SUM(has_multiple_splits_per_proc) as complex_split_count,
        SUM(is_large_payment) as large_payment_count,
        SUM(is_simple_payment) as simple_payment_count,
        SUM(has_high_split_ratio) as high_ratio_count,
        SUM(has_oversplit_claims) as oversplit_claim_count
    FROM PaymentFilterDiagnostics
    GROUP BY filter_reason
),

-- 20. ProblemPayments: Pre-filter payments flagged as problematic for detailed analysis.
ProblemPayments AS (
    SELECT *
    FROM PaymentFilterDiagnostics
    WHERE filter_reason != 'Normal Payment'
),

-- 21. ClaimMetrics: Analyze claim relationships for payment split analysis.
ClaimMetrics AS (
    SELECT 
        ps.PayNum,
        COUNT(DISTINCT cp.ClaimProcNum) as claimproc_count,
        GROUP_CONCAT(DISTINCT cp.ClaimNum) as claim_nums,
        COUNT(DISTINCT CASE WHEN cp.ClaimNum IN (2536, 2542, 6519) THEN cp.ClaimNum END) as common_claim_count,
        COUNT(DISTINCT cp.ClaimNum) as total_claim_count
    FROM paysplit ps
    JOIN payment p ON ps.PayNum = p.PayNum
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
        AND cp.Status IN (1, 4, 5)
        AND cp.InsPayAmt > 0
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY ps.PayNum
),

-- 22. ProblemClaimDetails: Detailed analysis of known problematic claims.
ProblemClaimDetails AS (
    SELECT 
        cp.ClaimNum,
        cp.ClaimProcNum,
        COUNT(DISTINCT p.PayNum) as payment_count,
        COUNT(ps.SplitNum) as split_count,
        MIN(ps.SplitAmt) as min_split_amt,
        MAX(ps.SplitAmt) as max_split_amt,
        COUNT(DISTINCT DATE(p.PayDate)) as active_days
    FROM claimproc cp
    JOIN paysplit ps ON cp.ProcNum = ps.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE cp.ClaimNum IN (2536, 2542, 6519)
        AND p.PayDate BETWEEN '2024-10-30' AND '2024-11-05'
    GROUP BY cp.ClaimNum, cp.ClaimProcNum
)
