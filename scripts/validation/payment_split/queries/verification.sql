-- Verification counts
-- base counts and join verification
-- payment tracking through stages

SELECT 
    'verification_counts' as report_type,
    'Total Base Payments' as metric,
    total_payments as payment_count,
    min_date,
    max_date
FROM PaymentBaseCounts

UNION ALL

SELECT 
    'verification_counts' as report_type,
    join_status as metric,
    COUNT(*) as payment_count,
    MIN(PayDate) as min_date,
    MAX(PayDate) as max_date
FROM PaymentJoinDiagnostics
GROUP BY join_status;
