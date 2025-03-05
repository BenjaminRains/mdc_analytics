-- BaseSplits: Pre-aggregate split details for base payments.
-- depends on: BasePayments
-- Date filter: Uses @start_date to @end_date
BaseSplits AS (
    SELECT 
        ps.PayNum,
        COUNT(DISTINCT ps.SplitNum) AS split_count,
        COUNT(DISTINCT ps.ProcNum) AS proc_count,
        SUM(ps.SplitAmt) AS total_split_amount
    FROM paysplit ps
    JOIN BasePayments p ON ps.PayNum = p.PayNum
    GROUP BY ps.PayNum
)