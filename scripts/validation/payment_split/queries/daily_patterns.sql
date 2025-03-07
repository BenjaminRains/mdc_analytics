-- Investigate daily patterns of the payment process. This query looks at payment patterns by day to identify abnormal activity
-- It helps identify days with unusual payment volumes or amounts
-- Uses DailyStats CTE for aggregation
-- Date filter: Use @start_date to @end_date variables
-- Include CTEs
<<include:daily_stats.sql>>

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
