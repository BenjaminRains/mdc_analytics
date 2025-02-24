-- Diagnostic summary
-- detailed diagnostic metrics by filter
-- average splits, min/max amounts
-- uses PaymentFilterDiagnostics CTE

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
