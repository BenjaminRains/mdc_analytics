{% include "payment_level_metrics.sql" %}
PaymentMethodAnalysis AS (
    SELECT 
        p.PayType,
        COUNT(*) AS payment_count,
        SUM(p.PayAmt) AS total_amount,
        COUNT(CASE WHEN p.PayAmt < 0 THEN 1 END) AS reversal_count,
        AVG(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS error_rate,
        MIN(p.PayAmt) AS min_amount,
        MAX(p.PayAmt) AS max_amount,
        COUNT(CASE WHEN p.PayAmt = 0 THEN 1 END) AS zero_count,
        ps.payment_category
    FROM payment p
    JOIN PaymentLevelMetrics ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayType, ps.payment_category
)