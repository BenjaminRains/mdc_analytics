<<include:payment_filter_diagnostics.sql>>
SELECT 
    'problem_details' as report_type,
    pfd.PayNum,
    pfd.PayAmt,
    pfd.filter_reason,
    pfd.join_status,
    pfd.split_count,
    pfd.proc_count,
    pfd.has_multiple_splits_per_proc as is_complex_split,
    pfd.is_large_payment,
    pfd.has_high_split_ratio,
    pfd.has_oversplit_claims,
    CASE 
        WHEN pfd.proc_count > 0 THEN ROUND(pfd.split_count * 1.0 / pfd.proc_count, 1)
        ELSE NULL 
    END as splits_per_proc,
    CASE 
        WHEN pfd.has_oversplit_claims = 1 THEN 'High'
        WHEN pfd.has_high_split_ratio = 1 THEN 'High'
        WHEN pfd.has_multiple_splits_per_proc = 1 AND pfd.is_large_payment = 1 THEN 'High'
        WHEN pfd.has_multiple_splits_per_proc = 1 THEN 'Medium'
        WHEN pfd.is_large_payment = 1 THEN 'Medium'
        ELSE 'Low'
    END as priority
FROM PaymentFilterDiagnostics pfd
WHERE filter_reason != 'Normal Payment'
    AND (
        has_multiple_splits_per_proc = 1 OR
        is_large_payment = 1 OR
        has_high_split_ratio = 1 OR
        has_oversplit_claims = 1
    )
ORDER BY 
    CASE priority 
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    PayAmt DESC;