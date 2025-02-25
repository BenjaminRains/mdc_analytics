-- Monthly Unpaid Procedures Query
-- Analyzes unpaid completed procedures by month to identify trends

WITH 
UnpaidCompleted AS (
    SELECT 
        pl.ProcNum,
        pl.ProcDate,
        EXTRACT(MONTH FROM pl.ProcDate) AS proc_month,
        pl.ProcFee,
        pa.total_paid
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcStatus = 2 -- Completed
      AND pl.ProcFee > 0 -- Has a fee
      AND pl.CodeCategory = 'Standard' -- Not an excluded code
      AND (pa.total_paid IS NULL OR pa.total_paid = 0) -- No payments
)

SELECT 
    proc_month,
    COUNT(*) AS unpaid_count,
    SUM(ProcFee) AS unpaid_fees,
    ROUND(AVG(ProcFee), 2) AS avg_unpaid_fee,
    MIN(ProcFee) AS min_fee,
    MAX(ProcFee) AS max_fee,
    COUNT(DISTINCT CASE WHEN ProcFee >= 1000 THEN ProcNum ELSE NULL END) AS high_value_count
FROM UnpaidCompleted
GROUP BY proc_month
ORDER BY proc_month; 