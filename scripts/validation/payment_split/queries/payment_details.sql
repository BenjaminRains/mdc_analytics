-- Analyze individual payment details and their split patterns
-- This query helps identify unusual payment behaviors and split patterns. Note the configurable thresholds for split volume and split difference.
-- Date filter: Use @start_date to @end_date variables

, PaymentDetailsBaseOverride AS (
    SELECT 
        p.PayNum,
        p.PayDate,
        p.PayType,
        p.PayAmt,
        p.PayNote,
        ps.SplitNum,
        ps.SplitAmt,
        ps.ProcNum,
        cp.ClaimNum
    FROM payment p
    JOIN paysplit ps ON p.PayNum = ps.PayNum
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    JOIN claim c ON cp.ClaimNum = c.ClaimNum
    WHERE p.PayDate BETWEEN @start_date AND @end_date
),

PaymentDetailsMetricsOverride AS (
    SELECT 
        PayNum,
        PayDate,
        PayType,
        PayAmt,
        PayNote,
        COUNT(SplitNum) as splits_in_payment,
        COUNT(DISTINCT ClaimNum) as claims_in_payment,
        COUNT(DISTINCT ProcNum) as procedures_in_payment,
        MIN(SplitAmt) as min_split,
        MAX(SplitAmt) as max_split,
        SUM(SplitAmt) as total_split_amount,
        ABS(PayAmt - SUM(SplitAmt)) as split_difference
    FROM PaymentDetailsBaseOverride
    GROUP BY PayNum, PayDate, PayType, PayAmt, PayNote
)

SELECT 
    pm.*,
    CASE 
        WHEN splits_in_payment > 1000 THEN 'High Volume'
        WHEN splits_in_payment > 100 THEN 'Multiple'
        WHEN splits_in_payment > 10 THEN 'Complex'
        ELSE 'Normal'
    END as split_volume_category,
    CASE 
        WHEN ABS(min_split) = ABS(max_split) THEN 'Symmetric'
        ELSE 'Variable'
    END as split_pattern
FROM PaymentDetailsMetricsOverride pm
WHERE 
    splits_in_payment > 10  -- Configurable threshold
    OR split_difference > 0.01  -- Detect mismatches
ORDER BY splits_in_payment DESC, PayDate;
