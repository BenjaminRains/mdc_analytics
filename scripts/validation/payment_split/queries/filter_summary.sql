-- Filter summary (consolidated with diagnostic)
-- filter reason breakdown with validation
-- payment counts, amounts and diagnostic metrics by category
-- uses FilterStats CTE from ctes.sql
-- uses PaymentFilterDiagnostics CTE from ctes.sql

WITH FilterDiagnosticMetrics AS (
    -- Calculate metrics by filter reason that aren't in FilterStats
    SELECT 
        filter_reason,
        AVG(split_count) as avg_splits,
        MIN(PayAmt) as min_amount,
        MAX(PayAmt) as max_amount
    FROM PaymentFilterDiagnostics
    GROUP BY filter_reason
)

SELECT 
    fs.filter_reason,
    fs.payment_count,
    fs.percentage,
    fs.total_amount,
    fs.avg_amount,
    -- Diagnostic metrics from the supplementary CTE
    fdm.avg_splits,
    fdm.min_amount,
    fdm.max_amount,
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
JOIN FilterDiagnosticMetrics fdm ON fs.filter_reason = fdm.filter_reason
ORDER BY fs.payment_count DESC;
