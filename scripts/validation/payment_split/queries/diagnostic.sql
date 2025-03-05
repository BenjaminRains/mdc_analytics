-- Diagnostic summary
-- advanced diagnostic metrics by filter category
-- split patterns, correlation between filter types and issues
-- uses PaymentFilterDiagnostics CTE from ctes.sql
-- Date filter: Use @start_date to @end_date variables

SELECT 
    'diagnostic_correlation' as report_type,
    filter_reason,
    -- Split pattern analysis
    COUNT(*) as payment_count,
    AVG(split_count) as avg_splits,
    ROUND(AVG(split_count * 1.0 / NULLIF(proc_count, 0)), 2) as avg_splits_per_proc,
    -- Issue correlation
    SUM(has_multiple_splits_per_proc) as complex_split_count,
    SUM(has_multiple_splits_per_proc) * 100.0 / NULLIF(COUNT(*), 0) as pct_complex,
    SUM(is_large_payment) as large_payment_count,
    SUM(is_large_payment) * 100.0 / NULLIF(COUNT(*), 0) as pct_large,
    SUM(is_simple_payment) as simple_payment_count,
    SUM(is_simple_payment) * 100.0 / NULLIF(COUNT(*), 0) as pct_simple,
    SUM(has_high_split_ratio) as high_ratio_count,
    SUM(has_high_split_ratio) * 100.0 / NULLIF(COUNT(*), 0) as pct_high_ratio,
    SUM(has_oversplit_claims) as oversplit_claim_count,
    SUM(has_oversplit_claims) * 100.0 / NULLIF(COUNT(*), 0) as pct_oversplit
FROM PaymentFilterDiagnostics
GROUP BY filter_reason
ORDER BY payment_count DESC;
