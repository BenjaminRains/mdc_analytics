WITH RECURSIVE PaymentDetailsBase AS (
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
    WHERE p.PayDate >= @start_date AND p.PayDate < @end_date
), PaymentDetailsMetrics AS (
    SELECT 
        PayNum,
        PayDate,
        PayType,
        PayAmt,
        PayNote,
        COUNT (SplitNum) as splits_in_payment,
        COUNT (DISTINCT ClaimNum) as claims_in_payment,
        COUNT (DISTINCT ProcNum) as procedures_in_payment,
        MIN (SplitAmt) as min_split,
        MAX (SplitAmt) as max_split,
        SUM (SplitAmt) as total_split_amount,
        ABS (PayAmt - SUM (SplitAmt)) as split_difference
    FROM PaymentDetailsBase
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
        WHEN ABS (min_split) = ABS (max_split) THEN 'Symmetric'
        ELSE 'Variable'
    END as split_pattern
FROM PaymentDetailsMetrics pm
WHERE 
    splits_in_payment > 10  
    OR split_difference > 0.01  
ORDER BY splits_in_payment DESC, PayDate;