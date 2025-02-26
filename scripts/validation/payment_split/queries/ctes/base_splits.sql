-- BaseSplits: Pre-aggregate split details for base payments.
-- depends on: BasePayments
-- Date filter: 2024-01-01 to 2025-01-01
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