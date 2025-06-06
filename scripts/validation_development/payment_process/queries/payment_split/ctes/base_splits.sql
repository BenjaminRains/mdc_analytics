{% include "base_payments.sql" %}
-- Payment split aggregation metrics - provides split counts and amounts per payment
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