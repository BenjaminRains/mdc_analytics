-- PaymentBaseCounts: Compute overall payment volume metrics.
-- depends on: none
-- Date filter: 2024-01-01 to 2025-01-01
PaymentBaseCounts AS (
    SELECT 
        'base_counts' as metric,
        COUNT(DISTINCT p.PayNum) as total_payments,
        (SELECT COUNT(*) FROM paysplit ps2 
         JOIN payment p2 ON ps2.PayNum = p2.PayNum 
         WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') as total_splits,
        (SELECT COUNT(DISTINCT pl2.ProcNum) 
         FROM procedurelog pl2 
         JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
         JOIN payment p2 ON ps2.PayNum = p2.PayNum
         WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') as total_procedures,
        SUM(p.PayAmt) as total_amount,
        AVG(p.PayAmt) as avg_payment,
        COUNT(CASE WHEN p.PayAmt < 0 THEN 1 END) as negative_payments,
        COUNT(CASE WHEN p.PayAmt = 0 THEN 1 END) as zero_payments,
        MIN(p.PayDate) as min_date,
        MAX(p.PayDate) as max_date,
        CAST((SELECT COUNT(*) FROM paysplit ps2 
              JOIN payment p2 ON ps2.PayNum = p2.PayNum 
              WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') AS FLOAT) / 
            COUNT(DISTINCT p.PayNum) as avg_splits_per_payment,
        (SELECT COUNT(DISTINCT pl2.ProcNum) 
         FROM procedurelog pl2 
         JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
         JOIN payment p2 ON ps2.PayNum = p2.PayNum
         WHERE p2.PayDate >= '2024-01-01' AND p2.PayDate < '2025-01-01') * 1.0 / 
            COUNT(DISTINCT p.PayNum) as avg_procedures_per_payment
    FROM payment p
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY 'base_counts'
)