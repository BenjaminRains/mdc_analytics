WITH RECURSIVE BasePayments AS (
    SELECT PayNum, PayDate, PayAmt, PayType
    FROM payment 
    WHERE PayDate >= @start_date AND PayDate < @end_date
), BaseSplits AS (
    SELECT 
        ps.PayNum,
        COUNT (DISTINCT ps.SplitNum) AS split_count,
        COUNT (DISTINCT ps.ProcNum) AS proc_count,
        SUM (ps.SplitAmt) AS total_split_amount
    FROM paysplit ps
    JOIN BasePayments p ON ps.PayNum = p.PayNum
    GROUP BY ps.PayNum
), PaymentLevelMetrics AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        p.PayNote,
        COUNT (ps.SplitNum) AS split_count,
        SUM (ps.SplitAmt) AS total_split_amount,
        ABS (p.PayAmt - COALESCE (SUM (ps.SplitAmt), 0)) AS split_difference,
        CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal,
        CASE WHEN COUNT (ps.SplitNum) > 15 THEN 1 ELSE 0 END AS is_high_split,
        CASE WHEN p.PayAmt = 0 THEN 1 ELSE 0 END AS is_zero_amount,
        CASE WHEN p.PayAmt > 5000 THEN 1 ELSE 0 END AS is_large_payment,
        CASE WHEN COUNT (ps.SplitNum) = 1 THEN 1 ELSE 0 END AS is_single_split,
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
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
), PaymentMethodAnalysis AS (
    SELECT 
        p.PayType,
        COUNT (*) AS payment_count,
        SUM (p.PayAmt) AS total_amount,
        COUNT (CASE WHEN p.PayAmt < 0 THEN 1 END) AS reversal_count,
        AVG (CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS error_rate,
        MIN (p.PayAmt) AS min_amount,
        MAX (p.PayAmt) AS max_amount,
        COUNT (CASE WHEN p.PayAmt = 0 THEN 1 END) AS zero_count,
        ps.payment_category
    FROM payment p
    JOIN PaymentLevelMetrics ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayType, ps.payment_category
), PaymentSourceCategories AS (
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
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
), PaymentSourceSummary AS (
    SELECT 
        pc.payment_source,
        COUNT (*) AS payment_count,
        SUM (pc.PayAmt) AS total_paid,
        MIN (pc.PayDate) AS min_date,
        MAX (pc.PayDate) AS max_date,
        AVG (pc.PayAmt) AS avg_payment
    FROM PaymentSourceCategories pc
    GROUP BY pc.payment_source
), InsurancePaymentAnalysis AS (
    SELECT 
        pss.payment_source,
        pss.payment_count,
        pss.total_paid,
        pss.avg_payment,
        COUNT (DISTINCT cp.PlanNum) AS plan_count,
        COUNT (DISTINCT cp.ClaimNum) AS claim_count,
        COUNT (DISTINCT CASE WHEN p.PayType IN (417, 574, 634) THEN p.PayNum END) AS direct_ins_count,
        COUNT (DISTINCT CASE WHEN p.PayType IN (69, 70, 71) THEN p.PayNum END) AS check_cash_count,
        COUNT (DISTINCT CASE WHEN p.PayType IN (391, 412) THEN p.PayNum END) AS card_count,
        AVG (CASE 
            WHEN pl.ProcDate IS NOT NULL THEN DATEDIFF (p.PayDate, pl.ProcDate)
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
), ProcedurePayments AS (
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
        DATEDIFF (p.PayDate, pl.ProcDate) AS days_to_payment,
        ROW_NUMBER () OVER (PARTITION BY pl.ProcNum ORDER BY p.PayDate) AS payment_sequence,
        CASE 
            WHEN pl.ProcStatus = 1 THEN 'Complete'
            WHEN pl.ProcStatus = 2 THEN 'Existing'
            ELSE 'Other'
        END AS proc_status_desc,
        CASE WHEN ps.UnearnedType = 439 THEN 1 ELSE 0 END as is_prepayment,
        CASE WHEN DATEDIFF (p.PayDate, pl.ProcDate) < 0 THEN 1 ELSE 0 END as is_advance_payment,
        CASE 
            WHEN pl.ProcStatus = 1 AND pl.ProcFee > 1000 THEN 'major'
            WHEN pl.ProcStatus = 1 THEN 'minor'
            WHEN pl.ProcStatus = 2 THEN 'existing'
            ELSE 'other'
        END as procedure_category
    FROM procedurelog pl
    JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
), SplitPatternAnalysis AS (
    SELECT 
        ProcNum,
        COUNT (DISTINCT PayNum) AS payment_count,
        COUNT (*) AS split_count,
        SUM (SplitAmt) AS total_paid,
        AVG (days_to_payment) AS avg_days_to_payment,
        CASE 
            WHEN COUNT (*) = 1 THEN 'single_payment'
            WHEN COUNT (*) = 2 THEN 'double_payment'
            WHEN COUNT (*) BETWEEN 3 AND 5 THEN 'multiple_payment'
            WHEN COUNT (*) BETWEEN 6 AND 15 THEN 'complex_payment'
            ELSE 'review_needed'
        END AS split_pattern,
        MIN (days_to_payment) AS first_payment_days,
        MAX (days_to_payment) AS last_payment_days,
        DATEDIFF (MAX (PayDate), MIN (PayDate)) AS payment_span_days,
        MIN (SplitAmt) AS min_split_amount,
        MAX (SplitAmt) AS max_split_amount,
        CASE WHEN COUNT (*) > COUNT (DISTINCT PayNum) * 2 THEN 1 ELSE 0 END AS has_multiple_splits_per_payment,
        CASE WHEN MAX (days_to_payment) - MIN (days_to_payment) > 365 THEN 1 ELSE 0 END AS is_long_term_payment,
        GROUP_CONCAT (
            DISTINCT 
            CASE payment_sequence 
                WHEN 1 THEN 'First' 
                WHEN 2 THEN 'Second' 
                WHEN 3 THEN 'Third' 
                WHEN 4 THEN 'Fourth'
                WHEN 5 THEN 'Fifth'
                ELSE CONCAT (payment_sequence) 
            END
            ORDER BY payment_sequence
            SEPARATOR ' > '
        ) AS payment_sequence_pattern
    FROM ProcedurePayments
    GROUP BY ProcNum
), PaymentBaseCounts AS (
    SELECT 
        'base_counts' as metric,
        COUNT (DISTINCT p.PayNum) as total_payments,
        (SELECT COUNT (*) FROM paysplit ps2 
         JOIN payment p2 ON ps2.PayNum = p2.PayNum 
         WHERE p2.PayDate >= @start_date AND p2.PayDate < @end_date) as total_splits,
        (SELECT COUNT (DISTINCT pl2.ProcNum) 
         FROM procedurelog pl2 
         JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
         JOIN payment p2 ON ps2.PayNum = p2.PayNum
         WHERE p2.PayDate >= @start_date AND p2.PayDate < @end_date) as total_procedures,
        SUM (p.PayAmt) as total_amount,
        AVG (p.PayAmt) as avg_payment,
        COUNT (CASE WHEN p.PayAmt < 0 THEN 1 END) as negative_payments,
        COUNT (CASE WHEN p.PayAmt = 0 THEN 1 END) as zero_payments,
        MIN (p.PayDate) as min_date,
        MAX (p.PayDate) as max_date,
        CAST ((SELECT COUNT (*) FROM paysplit ps2 
              JOIN payment p2 ON ps2.PayNum = p2.PayNum 
              WHERE p2.PayDate >= @start_date AND p2.PayDate < @end_date) AS FLOAT) / 
            COUNT (DISTINCT p.PayNum) as avg_splits_per_payment,
        (SELECT COUNT (DISTINCT pl2.ProcNum) 
         FROM procedurelog pl2 
         JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
         JOIN payment p2 ON ps2.PayNum = p2.PayNum
         WHERE p2.PayDate >= @start_date AND p2.PayDate < @end_date) * 1.0 / 
            COUNT (DISTINCT p.PayNum) as avg_procedures_per_payment
    FROM payment p
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY 'base_counts'
), PaymentJoinDiagnostics AS (
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
        COUNT (DISTINCT ps.SplitNum) as split_count,
        COUNT (DISTINCT pl.ProcNum) as proc_count
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    LEFT JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayNum, p.PayDate, p.PayAmt, p.PayType
), PaymentFilterDiagnostics AS (
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
                 AND (split_count * 1.0 / proc_count) > 10 
            THEN 1 ELSE 0 
        END as has_high_split_ratio,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM paysplit ps2 
                JOIN claimproc cp2 ON ps2.ProcNum = cp2.ProcNum
                WHERE ps2.PayNum = pd.PayNum
                GROUP BY cp2.ClaimNum
                HAVING COUNT (*) > 1000
            ) THEN 1 ELSE 0 
        END as has_oversplit_claims
    FROM PaymentJoinDiagnostics pd
), ProblemPayments AS (
    SELECT *
    FROM PaymentFilterDiagnostics
    WHERE filter_reason != 'Normal Payment'
)
SELECT * FROM (
    SELECT 
        'summary' AS report_type,
        pbc.total_payments AS base_payment_count,
        COUNT (DISTINCT pfd.PayNum) AS filtered_payment_count,
        AVG (pfd.split_count) AS avg_splits_per_payment,
        SUM (CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS payments_with_split_mismatch,
        COUNT (DISTINCT pma.PayType) AS payment_method_count,
        MAX (pma.reversal_count) AS total_reversals,
        SUM (CASE WHEN ipa.payment_source = 'Insurance' THEN ipa.payment_count ELSE 0 END) AS insurance_payments,
        SUM (CASE WHEN ipa.payment_source = 'Patient' THEN ipa.payment_count ELSE 0 END) AS patient_payments,
        COUNT (CASE WHEN spa.split_pattern IN ('single_payment','double_payment','multiple_payment') THEN 1 END) AS normal_split_count,
        COUNT (CASE WHEN spa.split_pattern = 'complex_payment' THEN 1 ELSE 0 END) AS complex_split_count,
        COUNT (CASE WHEN spa.split_pattern = 'review_needed' THEN 1 ELSE 0 END) AS review_needed_count,
        AVG (spa.avg_days_to_payment) AS avg_days_to_payment,
        MAX (spa.payment_count) AS max_payments_per_procedure,
        AVG (spa.payment_count) AS avg_payments_per_procedure,
        GROUP_CONCAT (DISTINCT CASE WHEN spa.split_count > 3 THEN spa.payment_sequence_pattern END) AS complex_payment_patterns,
        AVG (pp.ProcFee) AS avg_procedure_fee,
        AVG (spa.total_paid) AS avg_total_paid,
        COUNT (CASE WHEN spa.total_paid > pp.ProcFee THEN 1 ELSE 0 END) AS overpayment_count,
        COUNT (CASE WHEN pp.UnearnedType = 0 THEN 1 ELSE 0 END) AS regular_payment_count,
        COUNT (CASE WHEN pp.UnearnedType = 288 THEN 1 ELSE 0 END) AS prepayment_count,
        COUNT (CASE WHEN pp.UnearnedType = 439 THEN 1 ELSE 0 END) AS tp_prepayment_count,
        SUM (CASE WHEN pfd.filter_reason != 'Normal Payment' THEN 1 ELSE 0 END) AS problem_payment_count
    FROM PaymentBaseCounts pbc
    JOIN (SELECT DISTINCT 1 as join_key FROM PaymentFilterDiagnostics) pfd_key ON 1=1
    LEFT JOIN PaymentFilterDiagnostics pfd ON 1=1
    LEFT JOIN PaymentLevelMetrics ps ON pfd.PayNum = ps.PayNum
    LEFT JOIN ProcedurePayments pp ON pfd.PayNum = pp.PayNum
    LEFT JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
    LEFT JOIN PaymentMethodAnalysis pma ON ps.PayType = pma.PayType
    LEFT JOIN InsurancePaymentAnalysis ipa ON 1=1
    GROUP BY pbc.total_payments
    UNION ALL
    SELECT 
        'problem_detail' AS report_type,
        CAST (pfd.PayNum AS CHAR) AS base_payment_count,
        pfd.PayAmt AS filtered_payment_count,
        pfd.split_count AS avg_splits_per_payment,
        pfd.split_count AS payments_with_split_mismatch,
        NULL AS payment_method_count,
        NULL AS total_reversals,
        NULL AS insurance_payments,
        NULL AS patient_payments,
        pfd.split_count AS normal_split_count,
        pfd.split_count AS complex_split_count,
        CAST (pp.ProcNum AS CHAR) AS review_needed_count,
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
    FROM ProblemPayments pfd
    JOIN ProcedurePayments pp ON pfd.PayNum = pp.PayNum
    JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
) combined_results
ORDER BY report_type DESC;