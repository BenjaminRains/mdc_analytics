-- PaymentLevelMetrics: Compute basic payment metrics and categorize payments.
-- Date filter: Uses @start_date to @end_date
-- depends on: none
PaymentLevelMetrics AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        p.PayNote,
        COUNT(ps.SplitNum) AS split_count,
        SUM(ps.SplitAmt) AS total_split_amount,
        ABS(p.PayAmt - COALESCE(SUM(ps.SplitAmt), 0)) AS split_difference,
        CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal,
        CASE WHEN COUNT(ps.SplitNum) > 15 THEN 1 ELSE 0 END AS is_high_split,
        CASE WHEN p.PayAmt = 0 THEN 1 ELSE 0 END AS is_zero_amount,
        CASE WHEN p.PayAmt > 5000 THEN 1 ELSE 0 END AS is_large_payment,
        CASE WHEN COUNT(ps.SplitNum) = 1 THEN 1 ELSE 0 END AS is_single_split,
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'
            WHEN p.PayType IN (69, 70, 71) THEN 'Check/Cash'
            WHEN p.PayType IN (391, 412) THEN 'Card/Online'
            WHEN p.PayType = 72 THEN 'Refund'
            WHEN p.PayType = 0 THEN 'Transfer'
            ELSE 'Other'
        END AS payment_category
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
)