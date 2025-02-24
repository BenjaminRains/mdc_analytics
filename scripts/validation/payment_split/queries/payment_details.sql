-- Analyze individual payment details and their split patterns
-- This query helps identify unusual payment behaviors and split patterns
-- uses PaymentDetailsMetrics CTE from ctes.sql

SELECT 
    pm.*,
    CASE 
        WHEN splits_in_payment > 1000 THEN 'High Volume'
        WHEN splits_in_payment > 100 THEN 'Multiple'
        WHEN splits_in_payment > 10 THEN 'Complex'
        ELSE 'Normal'
    END as split_volume_category,
    CASE 
        WHEN ABS(min_split) = ABS(max_split) THEN 'Symmetric'
        ELSE 'Variable'
    END as split_pattern
FROM PaymentDetailsMetrics pm
WHERE 
    splits_in_payment > 10  -- Configurable threshold
    OR split_difference > 0.01  -- Detect mismatches
ORDER BY splits_in_payment DESC, PayDate;
