-- Filter summary (consolidated with diagnostic)
-- filter reason breakdown with validation
-- payment counts, amounts and diagnostic metrics by category
-- Date filter: Use @start_date to @end_date variables
-- Include dependent CTEs
<<include:payment_filter_diagnostics.sql>>
<<include:filter_stats.sql>>

SELECT 
    fs.filter_reason,
    fs.payment_count,
    fs.percentage,
    fs.total_amount,
    fs.avg_amount,
    -- Diagnostic metrics calculated directly
    (SELECT AVG(split_count) FROM PaymentFilterDiagnostics WHERE filter_reason = fs.filter_reason) as avg_splits,
    (SELECT MIN(PayAmt) FROM PaymentFilterDiagnostics WHERE filter_reason = fs.filter_reason) as min_amount,
    (SELECT MAX(PayAmt) FROM PaymentFilterDiagnostics WHERE filter_reason = fs.filter_reason) as max_amount,
    -- Validation flags
    CASE 
        WHEN fs.filter_reason = 'Zero Amount' AND fs.percentage != 13.1 
            THEN 'Unexpected: Should be 13.1%'
        WHEN fs.filter_reason = 'High Split Count' AND fs.percentage != 0.2 
            THEN 'Unexpected: Should be 0.2%'
        WHEN fs.filter_reason = 'Reversal' AND fs.percentage != 0.6 
            THEN 'Unexpected: Should be 0.6%'
        WHEN fs.filter_reason = 'No Insurance' AND fs.percentage != 38.8 
            THEN 'Unexpected: Should be 38.8%'
        WHEN fs.filter_reason = 'No Procedures' AND fs.percentage != 4.6 
            THEN 'Unexpected: Should be 4.6%'
        WHEN fs.filter_reason = 'Normal Payment' AND fs.percentage != 47.2 
            THEN 'Unexpected: Should be 47.2%'
        ELSE 'OK'
    END as validation_check,
    -- Additional metrics
    fs.complex_split_count,
    fs.large_payment_count,
    fs.simple_payment_count,
    fs.high_ratio_count,
    fs.oversplit_claim_count,
    'filter_validation' as report_type
FROM FilterStats fs
ORDER BY fs.payment_count DESC;
