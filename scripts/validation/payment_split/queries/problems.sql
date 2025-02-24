-- Problems
-- detailed problem payment records
-- top 100 issues by amount

SELECT 
    'problem_details' as report_type,
    pd.*
FROM PaymentFilterDiagnostics pd
WHERE filter_reason != 'Normal Payment'
ORDER BY PayAmt DESC
LIMIT 100;
