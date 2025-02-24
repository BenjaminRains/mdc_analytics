-- Filter summary
-- filter reason breakdown with validation
-- payment counts and amounts by category with expected percentages
-- uses FilterStats CTE from ctes.sql
-- uses PaymentFilterDiagnostics CTE from ctes.sql

SELECT 
    filter_reason,
    payment_count,
    percentage,
    total_amount,
    avg_amount,
    -- Validation flags
    CASE 
        WHEN filter_reason = 'Zero Amount' AND percentage != 13.1 
            THEN 'Unexpected: Should be 13.1%'
        WHEN filter_reason = 'High Split Count' AND percentage != 0.2 
            THEN 'Unexpected: Should be 0.2%'
        WHEN filter_reason = 'Reversal' AND percentage != 0.6 
            THEN 'Unexpected: Should be 0.6%'
        WHEN filter_reason = 'No Insurance' AND percentage != 15.1 
            THEN 'Unexpected: Should be 15.1%'
        WHEN filter_reason = 'No Procedures' AND percentage != 4.6 
            THEN 'Unexpected: Should be 4.6%'
        WHEN filter_reason = 'Normal Payment' AND percentage != 66.3 
            THEN 'Unexpected: Should be 66.3%'
        ELSE 'OK'
    END as validation_check,
    -- Additional metrics
    complex_split_count,
    large_payment_count,
    simple_payment_count,
    high_ratio_count,
    oversplit_claim_count,
    'filter_validation' as report_type
FROM FilterStats
ORDER BY payment_count DESC;
