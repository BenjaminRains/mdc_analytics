/*
Payment Split Analysis Query
===========================

Purpose:
- Analyzes payment splits, procedures, and insurance relationships
- Identifies problematic payment patterns
- Generates summary metrics and detailed problem records

Output Branches:
1. Summary Branch: Aggregated metrics and patterns
2. Problem Detail Branch: Individual problematic payments

Date Range: 2024-01-01 to 2024-12-31
*/
-- Include/reference CTEs from ctes.sql
-- uses BasePayments
-- uses BaseSplits
-- uses PaymentSummary
-- uses PaymentMethodAnalysis
-- uses InsurancePaymentAnalysis
-- uses ProcedurePayments
-- uses SplitPatternAnalysis
-- uses PaymentBaseCounts
-- uses PaymentFilterDiagnostics
-- uses ProblemPayments

-- Final output: union of summary and problem detail branches
SELECT * FROM (
    -- Summary Branch
    SELECT 
        'summary' AS report_type,
        pbc.total_payments AS base_payment_count,
        COUNT(DISTINCT pfd.PayNum) AS filtered_payment_count,
        AVG(pfd.split_count) AS avg_splits_per_payment,
        SUM(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS payments_with_split_mismatch,
        COUNT(DISTINCT pma.PayType) AS payment_method_count,
        MAX(pma.reversal_count) AS total_reversals,
        SUM(CASE WHEN ipa.payment_source = 'Insurance' THEN ipa.payment_count ELSE 0 END) AS insurance_payments,
        SUM(CASE WHEN ipa.payment_source = 'Patient' THEN ipa.payment_count ELSE 0 END) AS patient_payments,
        COUNT(CASE WHEN spa.split_pattern IN ('single_payment','double_payment','multiple_payment') THEN 1 END) AS normal_split_count,
        COUNT(CASE WHEN spa.split_pattern = 'complex_payment' THEN 1 ELSE 0 END) AS complex_split_count,
        COUNT(CASE WHEN spa.split_pattern = 'review_needed' THEN 1 ELSE 0 END) AS review_needed_count,
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
    FROM PaymentBaseCounts pbc
    JOIN (SELECT DISTINCT 1 as join_key FROM PaymentFilterDiagnostics) pfd_key ON 1=1
    LEFT JOIN PaymentFilterDiagnostics pfd ON 1=1
    LEFT JOIN PaymentSummary ps ON pfd.PayNum = ps.PayNum
    LEFT JOIN ProcedurePayments pp ON pfd.PayNum = pp.PayNum
    LEFT JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
    LEFT JOIN PaymentMethodAnalysis pma ON ps.PayType = pma.PayType
    LEFT JOIN InsurancePaymentAnalysis ipa ON 1=1
    GROUP BY pbc.total_payments

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
    FROM ProblemPayments pfd
    JOIN ProcedurePayments pp ON pfd.PayNum = pp.PayNum
    JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
) combined_results
ORDER BY report_type DESC;

/*
Expected Results:
- Summary row with aggregated metrics
- Problem detail rows for non-normal payments
- Split pattern distribution should match comments
- Payment counts should align with base metrics
*/
