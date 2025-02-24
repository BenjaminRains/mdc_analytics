-- This file contains the common table expressions (CTEs) used in the payment split validation queries.
-- It defines:
--   - PaymentSummary: Basic payment metrics and flags
--   - PaymentMethodAnalysis: Analysis by payment type
--   - InsurancePaymentAnalysis: Insurance-specific metrics
--   - ProcedurePayments: Procedure-level payment details
--   - SplitPatternAnalysis: Split pattern categorization
--   - PaymentBaseCounts: Overall volume metrics
--   - PaymentJoinDiagnostics: Data relationship checks
--   - PaymentFilterDiagnostics: Payment categorization

WITH PaymentSummary AS (
    -- Basic payment metrics and categorization
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        p.PayNote,
        COUNT(ps.SplitNum) AS split_count,
        SUM(ps.SplitAmt) AS total_split_amount,
        ABS(p.PayAmt - COALESCE(SUM(ps.SplitAmt), 0)) AS split_difference,
        -- Payment flags
        CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal,      -- 36 payments (0.6%), avg -$342.26
        CASE WHEN COUNT(ps.SplitNum) > 15 THEN 1 ELSE 0 END AS is_high_split,  -- 9 payments (0.2%), avg 19.1 splits
        CASE WHEN p.PayAmt = 0 THEN 1 ELSE 0 END AS is_zero_amount,   -- 743 payments (13.1%), avg 30.8 splits
        CASE WHEN p.PayAmt > 5000 THEN 1 ELSE 0 END AS is_large_payment,
        CASE WHEN COUNT(ps.SplitNum) = 1 THEN 1 ELSE 0 END AS is_single_split,
        -- Standard payment categorization
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'    -- 14 payments (0.2%), avg $6400-$25500
            WHEN p.PayType IN (69, 70, 71) THEN 'Check/Cash'      -- 4,482 payments (79.2%), avg $281-$1104
            WHEN p.PayType IN (391, 412) THEN 'Card/Online'       -- 385 payments (6.8%), avg $192-$938
            WHEN p.PayType = 72 THEN 'Refund'                     -- 34 payments (0.6%), all negative
            WHEN p.PayType = 0 THEN 'Transfer'                    -- 743 payments (13.1%), all zero amount
            ELSE 'Other'
        END AS payment_category
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
),

PaymentMethodAnalysis AS (
    -- Detailed analysis by payment type
    SELECT 
        p.PayType,
        COUNT(*) AS payment_count,
        SUM(p.PayAmt) AS total_amount,
        COUNT(CASE WHEN p.PayAmt < 0 THEN 1 END) AS reversal_count,
        AVG(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS error_rate,
        MIN(p.PayAmt) as min_amount,
        MAX(p.PayAmt) as max_amount,
        COUNT(CASE WHEN p.PayAmt = 0 THEN 1 END) as zero_count,
        ps.payment_category
    FROM payment p
    JOIN PaymentSummary ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayType, ps.payment_category
),

PaymentSourceCategories AS (
    -- Payment source categorization
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

PaymentSourceSummary AS (
    -- Summary metrics by source
    SELECT 
        pc.payment_source,
        COUNT(*) AS payment_count,
        SUM(pc.PayAmt) AS total_paid,
        MIN(pc.PayDate) as min_date,
        MAX(pc.PayDate) as max_date,
        AVG(pc.PayAmt) as avg_payment
    FROM PaymentSourceCategories pc
    GROUP BY pc.payment_source
),

InsurancePaymentAnalysis AS (
    -- Insurance-specific payment metrics
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

ProcedurePayments AS (
    -- Procedure-level payment details
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

SplitPatternAnalysis AS (
    -- Analysis of payment split patterns
    SELECT 
        ProcNum,
        COUNT(DISTINCT PayNum) AS payment_count,
        COUNT(*) AS split_count,
        SUM(SplitAmt) AS total_paid,
        AVG(days_to_payment) AS avg_days_to_payment,
        CASE 
            WHEN COUNT(*) = 1 THEN 'single_payment'      -- 14,949 procs (86.5%)
            WHEN COUNT(*) = 2 THEN 'double_payment'      -- 1,740 procs (10.1%)
            WHEN COUNT(*) BETWEEN 3 AND 5 THEN 'multiple_payment'  -- 508 procs (2.9%)
            WHEN COUNT(*) BETWEEN 6 AND 15 THEN 'complex_payment'  -- 85 procs (0.5%)
            ELSE 'review_needed'           -- 4 procs with >15 splits
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

PaymentBaseCounts AS (
    -- Overall payment volume metrics
    SELECT 
        'base_counts' as metric,
        COUNT(DISTINCT p.PayNum) as total_payments,        -- Should be 5,658
        (SELECT COUNT(*) FROM paysplit ps2 
         JOIN payment p2 ON ps2.PayNum = p2.PayNum 
         WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') as total_splits,  -- Should be 35,291
        (SELECT COUNT(DISTINCT pl2.ProcNum) 
         FROM procedurelog pl2 
         JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
         JOIN payment p2 ON ps2.PayNum = p2.PayNum
         WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') as total_procedures,  -- Should be 17,286
        SUM(p.PayAmt) as total_amount,
        AVG(p.PayAmt) as avg_payment,
        COUNT(CASE WHEN p.PayAmt < 0 THEN 1 END) as negative_payments,  -- Should be 36
        COUNT(CASE WHEN p.PayAmt = 0 THEN 1 END) as zero_payments,      -- Should be 743
        MIN(p.PayDate) as min_date,
        MAX(p.PayDate) as max_date,
        CAST((SELECT COUNT(*) FROM paysplit ps2 
              JOIN payment p2 ON ps2.PayNum = p2.PayNum 
              WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') AS FLOAT) / 
            COUNT(DISTINCT p.PayNum) as avg_splits_per_payment,  -- Should be ~6.24
        CAST((SELECT COUNT(DISTINCT pl2.ProcNum) 
              FROM procedurelog pl2 
              JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
              JOIN payment p2 ON ps2.PayNum = p2.PayNum
              WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') AS FLOAT) / 
            COUNT(DISTINCT p.PayNum) as avg_procedures_per_payment  -- Should be ~3.05
    FROM payment p
    WHERE p.PayDate >= '2024-01-01'
        AND p.PayDate < '2025-01-01'
    GROUP BY 'base_counts'
),

PaymentJoinDiagnostics AS (
    -- Analysis of data relationships
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
    GROUP BY 
        p.PayNum,
        p.PayDate,
        p.PayAmt,
        p.PayType
),

PaymentFilterDiagnostics AS (
    -- Payment categorization and filtering
    SELECT 
        pd.PayNum,
        pd.PayAmt,
        pd.join_status,
        pd.split_count,
        pd.proc_count,
        CASE
            WHEN pd.PayAmt = 0 THEN 'Zero Amount'          -- 743 payments (13.1%), avg 30.8 splits
            WHEN pd.split_count > 15 THEN 'High Split Count' -- 9 payments (0.2%), avg 19.1 splits
            WHEN pd.PayAmt < 0 THEN 'Reversal'            -- 36 payments (0.6%), all single split
            WHEN pd.join_status = 'No Insurance' THEN 'No Insurance'    -- 855 payments (15.1%)
            WHEN pd.join_status = 'No Procedures' THEN 'No Procedures'  -- 261 payments (4.6%)
            ELSE 'Normal Payment'                          -- 3,754 payments (66.3%)
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

JoinStageCounts AS (
    -- Analysis of payment progression through join stages
    -- Tracks expected patterns and validates relationships
    SELECT 
        pbc.total_payments as base_count,
        -- Split stages
        COUNT(DISTINCT CASE WHEN pjd.join_status != 'No Splits' THEN pjd.PayNum END) as with_splits,
        COUNT(DISTINCT CASE WHEN pjd.join_status NOT IN ('No Splits', 'No Procedures') THEN pjd.PayNum END) as with_procedures,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'Complete' THEN pjd.PayNum END) as with_insurance,
        -- Payment categories
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Insurance' AND pjd.PayAmt > 0 THEN pjd.PayNum END) as patient_payments,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt = 0 THEN pjd.PayNum END) as transfer_count,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt < 0 THEN pjd.PayNum END) as refund_count,
        -- Split analysis
        AVG(ps.split_count) as avg_splits_per_payment,
        COUNT(DISTINCT CASE WHEN ps.split_difference > 0.01 THEN ps.PayNum END) as mismatch_count,
        -- Additional metrics
        COUNT(DISTINCT CASE WHEN pjd.split_count > 15 THEN pjd.PayNum END) as high_split_count,
        COUNT(DISTINCT CASE WHEN pjd.split_count = 1 THEN pjd.PayNum END) as single_split_count,
        COUNT(DISTINCT CASE WHEN pjd.PayAmt > 5000 THEN pjd.PayNum END) as large_payment_count
    FROM PaymentBaseCounts pbc
    CROSS JOIN PaymentJoinDiagnostics pjd
    LEFT JOIN PaymentSummary ps ON pjd.PayNum = ps.PayNum
    GROUP BY pbc.total_payments
),

SuspiciousSplitAnalysis AS (
    -- Tracks high-volume symmetric splits on monitored claims
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

PaymentDetailsBase AS (
    -- Base payment and split information for detailed analysis
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

PaymentDetailsMetrics AS (
    -- Calculate detailed metrics per payment
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
    GROUP BY 
        PayNum,
        PayDate,
        PayType,
        PayAmt,
        PayNote
),

PaymentDailyDetails AS (
    -- Daily payment patterns and metrics
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
    WHERE p.PayDate >= DATEADD(month, -1, CURRENT_TIMESTAMP)  -- Configurable date range
),

FilterStats AS (
    -- Summary statistics for each filter category
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
)

-- Note: This file contains only CTEs. These are used by other queries for payment validation analysis.
