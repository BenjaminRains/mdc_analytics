-- This file contains the common table expressions (CTEs) used in the payment split validation queries.
-- It defines the base counts, payment summary, payment method analysis, insurance payment analysis,
-- procedure payments, split pattern analysis, and payment filter diagnostics.

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
