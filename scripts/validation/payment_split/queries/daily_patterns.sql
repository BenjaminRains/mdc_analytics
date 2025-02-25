-- Investigate daily patterns of the payment process. 
-- Uses PaymentDailyDetails CTE

-- Daily payment pattern analysis
-- This query looks at payment patterns by day to identify abnormal activity
-- It helps identify days with unusual payment volumes or amounts

-- First get base daily counts
DailyStats AS (
    SELECT 
        DATE(pdd.PayDate) as payment_date,
        COUNT(DISTINCT pdd.PayNum) as payment_count,
        COUNT(pdd.SplitNum) as split_count,
        COUNT(DISTINCT pdd.ClaimNum) as claim_count,
        COUNT(DISTINCT pdd.ProcNum) as procedure_count,
        SUM(pdd.PayAmt) as total_payment_amount,
        SUM(pdd.SplitAmt) as total_split_amount,
        ABS(SUM(pdd.PayAmt) - SUM(pdd.SplitAmt)) as payment_split_difference,
        COUNT(DISTINCT CASE WHEN pdd.PayType = 0 THEN pdd.PayNum END) as transfer_count,
        COUNT(DISTINCT CASE WHEN pdd.PayType IN (417, 574, 634) THEN pdd.PayNum END) as insurance_count
    FROM PaymentDailyDetails pdd
    GROUP BY DATE(pdd.PayDate)
)

-- Then calculate the rolling averages and ratios
SELECT 
    ds.*,
    
    -- Calculate 7-day rolling average properly
    AVG(ds.split_count) OVER(ORDER BY ds.payment_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as rolling_avg_splits,
    
    -- Split ratio metrics
    ROUND(ds.split_count / NULLIF(ds.payment_count, 0), 1) as splits_per_payment,
    ROUND(ds.split_count / NULLIF(ds.claim_count, 0), 1) as splits_per_claim,
    
    -- Identify days with high volume
    CASE
        WHEN ds.split_count > 10000 THEN 'Very High'
        WHEN ds.split_count > 5000 THEN 'High'
        WHEN ds.split_count > 1000 THEN 'Normal'
        ELSE 'Low'
    END as volume_category,
    
    -- Flag days with unusual payment/split ratio
    CASE
        WHEN ROUND(ds.split_count / NULLIF(ds.payment_count, 0), 1) > 20 THEN 'Suspicious'
        WHEN ROUND(ds.split_count / NULLIF(ds.payment_count, 0), 1) > 10 THEN 'Unusual'
        ELSE 'Normal'
    END as ratio_category
FROM DailyStats ds
ORDER BY ds.payment_date DESC;
