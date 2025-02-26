-- Payment and split base counts
-- This query is used to validate the payment and split base counts
-- CTEs used: PaymentBaseCounts
-- Date range: 2024-01-01 to 2025-01-01

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
JOIN payment p ON p.PayDate >= '{{START_DATE}}' AND p.PayDate < '{{END_DATE}}'
LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
GROUP BY 
    pbc.metric,
    pbc.total_payments,
    pbc.min_date,
    pbc.max_date;
