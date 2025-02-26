-- PaymentDetailsMetrics: Compute detailed metrics per payment.
-- depends on: PaymentDetailsBase
-- Date filter: 2024-01-01 to 2025-01-01
PaymentDetailsMetrics AS (
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
    FROM PaymentDetailsBase
    GROUP BY PayNum, PayDate, PayType, PayAmt, PayNote
)