WITH RECURSIVE PaymentDailyDetails AS (
    SELECT 
        p.PayNum,
        p.PayDate,
        p.PayType,
        p.PayAmt,
        p.PayNote,
        ps.SplitNum,
        ps.SplitAmt,
        ps.ProcNum,
        cp.ClaimNum,
        cp.ClaimProcNum,
        cp.Status as ProcStatus,
        c.ClaimStatus,
        c.DateService
    FROM payment p
    JOIN paysplit ps ON p.PayNum = ps.PayNum
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    JOIN claim c ON cp.ClaimNum = c.ClaimNum
    WHERE p.PayDate >= @start_date AND p.PayDate < @end_date
), DailyStats AS (
    SELECT 
        DATE (pdd.PayDate) as payment_date,
        COUNT (DISTINCT pdd.PayNum) as payment_count,
        COUNT (pdd.SplitNum) as split_count,
        COUNT (DISTINCT pdd.ClaimNum) as claim_count,
        COUNT (DISTINCT pdd.ProcNum) as procedure_count,
        SUM (pdd.PayAmt) as total_payment_amount,
        SUM (pdd.SplitAmt) as total_split_amount,
        ABS (SUM (pdd.PayAmt) - SUM (pdd.SplitAmt)) as payment_split_difference,
        COUNT (DISTINCT CASE WHEN pdd.PayType = 0 THEN pdd.PayNum END) as transfer_count,
        COUNT (DISTINCT CASE WHEN pdd.PayType IN (417, 574, 634) THEN pdd.PayNum END) as insurance_count
    FROM PaymentDailyDetails pdd
    GROUP BY DATE (pdd.PayDate)
) 
SELECT 
    ds.*,
    AVG (ds.split_count) OVER (ORDER BY ds.payment_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as rolling_avg_splits,
    ROUND (ds.split_count / NULLIF (ds.payment_count, 0), 1) as splits_per_payment,
    ROUND (ds.split_count / NULLIF (ds.claim_count, 0), 1) as splits_per_claim,
    CASE
        WHEN ds.split_count > 10000 THEN 'Very High'
        WHEN ds.split_count > 5000 THEN 'High'
        WHEN ds.split_count > 1000 THEN 'Normal'
        ELSE 'Low'
    END as volume_category,
    CASE
        WHEN ROUND (ds.split_count / NULLIF (ds.payment_count, 0), 1) > 20 THEN 'Suspicious'
        WHEN ROUND (ds.split_count / NULLIF (ds.payment_count, 0), 1) > 10 THEN 'Unusual'
        ELSE 'Normal'
    END as ratio_category
FROM DailyStats ds
ORDER BY ds.payment_date DESC;