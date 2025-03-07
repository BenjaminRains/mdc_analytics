WITH RECURSIVE PaymentSourceCategories AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'
            WHEN p.PayType = 0 THEN 'Transfer'
            WHEN p.PayType = 72 THEN 'Refund'
            WHEN EXISTS (
                SELECT 1 
                FROM paysplit ps2
                JOIN claimproc cp2 ON ps2.ProcNum = cp2.ProcNum
                WHERE ps2.PayNum = p.PayNum 
                  AND cp2.Status IN (1, 2, 4, 6)
            ) THEN 'Insurance'
            ELSE 'Patient'
        END as payment_source
    FROM payment p
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
),
PaymentSourceSummary AS (
    SELECT 
        pc.payment_source,
        COUNT (*) AS payment_count,
        SUM (pc.PayAmt) AS total_paid,
        MIN (pc.PayDate) AS min_date,
        MAX (pc.PayDate) AS max_date,
        AVG (pc.PayAmt) AS avg_payment
    FROM PaymentSourceCategories pc
    GROUP BY pc.payment_source
),
TotalPayments AS (
    SELECT 
        SUM (payment_count) as total_count,
        SUM (total_paid) as total_amount
    FROM PaymentSourceSummary
)
SELECT 
    ps.payment_source,
    ps.payment_count,
    ps.total_paid,
    ps.avg_payment,
    CAST (ps.payment_count AS FLOAT) / tp.total_count as pct_of_total,
    CAST (ps.total_paid AS FLOAT) / NULLIF (tp.total_amount, 0) as pct_of_amount,
    DATEDIFF (ps.max_date, ps.min_date) as date_span_days
FROM PaymentSourceSummary ps
CROSS JOIN TotalPayments tp
ORDER BY ps.payment_count DESC;