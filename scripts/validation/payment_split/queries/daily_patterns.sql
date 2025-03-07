<<include:daily_stats.sql>>
SELECT 
    ds.*,
    AVG(ds.split_count) OVER(ORDER BY ds.payment_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as rolling_avg_splits,
    ROUND(ds.split_count / NULLIF(ds.payment_count, 0), 1) as splits_per_payment,
    ROUND(ds.split_count / NULLIF(ds.claim_count, 0), 1) as splits_per_claim,
    CASE
        WHEN ds.split_count > 10000 THEN 'Very High'
        WHEN ds.split_count > 5000 THEN 'High'
        WHEN ds.split_count > 1000 THEN 'Normal'
        ELSE 'Low'
    END as volume_category,
    CASE
        WHEN ROUND(ds.split_count / NULLIF(ds.payment_count, 0), 1) > 20 THEN 'Suspicious'
        WHEN ROUND(ds.split_count / NULLIF(ds.payment_count, 0), 1) > 10 THEN 'Unusual'
        ELSE 'Normal'
    END as ratio_category
FROM DailyStats ds
ORDER BY ds.payment_date DESC;