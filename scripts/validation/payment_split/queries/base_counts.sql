-- Payment and split base counts
SELECT 
    'Payment Counts' as metric,
    COUNT(DISTINCT p.PayNum) as total_payments,
    COUNT(DISTINCT ps.SplitNum) as total_splits,
    COUNT(DISTINCT ps.ProcNum) as total_procedures,
    CAST(COUNT(DISTINCT ps.SplitNum) AS FLOAT) / 
        NULLIF(COUNT(DISTINCT p.PayNum), 0) as avg_splits_per_payment
FROM payment p
LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
WHERE p.PayDate >= '2024-01-01'
    AND p.PayDate < '2025-01-01';
