-- Payment and split base counts
-- Uses PaymentBaseCounts CTE for consistent counting across queries

SELECT 
    pbc.metric,
    pbc.total_payments,
    COUNT(DISTINCT ps.SplitNum) as total_splits,
    COUNT(DISTINCT ps.ProcNum) as total_procedures,
    CAST(COUNT(DISTINCT ps.SplitNum) AS FLOAT) / 
        NULLIF(pbc.total_payments, 0) as avg_splits_per_payment,
    pbc.min_date,
    pbc.max_date
FROM PaymentBaseCounts pbc
CROSS JOIN payment p
LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
WHERE p.PayDate >= '2024-01-01'
    AND p.PayDate < '2025-01-01'
GROUP BY 
    pbc.metric,
    pbc.total_payments,
    pbc.min_date,
    pbc.max_date;
