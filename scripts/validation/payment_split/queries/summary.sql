-- 1. Main Analysis Output
-- summary of payment split validation
-- payment counts and amounts
-- split patterns and timing
-- payment method distributions
-- insurance payment analysis
-- procedure payments

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
