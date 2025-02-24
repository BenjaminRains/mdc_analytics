-- Filter summary
-- filter reason breakdown
-- payment counts and amounts by category

SELECT 
    'filter_summary' as report_type,
    filter_reason,
    COUNT(*) as payment_count,
    SUM(PayAmt) as total_amount
FROM PaymentFilterDiagnostics
GROUP BY filter_reason
ORDER BY payment_count DESC;
