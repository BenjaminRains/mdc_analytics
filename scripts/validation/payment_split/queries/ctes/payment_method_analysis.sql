-- PaymentMethodAnalysis: Detailed analysis by payment type.
-- depends on: PaymentSummary
-- Date filter: 2024-01-01 to 2025-01-01
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
    JOIN PaymentSummary ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayType, ps.payment_category
)