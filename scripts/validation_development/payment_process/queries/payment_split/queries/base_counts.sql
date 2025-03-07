{% include 'payment_base_counts.sql' %}
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
JOIN payment p ON p.PayDate >= @start_date AND p.PayDate < @end_date
LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
GROUP BY 
    pbc.metric,
    pbc.total_payments,
    pbc.min_date,
    pbc.max_date;
