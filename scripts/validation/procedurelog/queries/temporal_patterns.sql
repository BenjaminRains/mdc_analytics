-- Temporal Patterns Query
-- Analyzes procedures and payments across time

WITH 
MonthlyData AS (
    SELECT 
        EXTRACT(YEAR FROM pl.ProcDate) AS proc_year,
        EXTRACT(MONTH FROM pl.ProcDate) AS proc_month,
        COUNT(*) AS total_procedures,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_procedures,
        SUM(CASE WHEN pl.ProcStatus = 1 THEN 1 ELSE 0 END) AS planned_procedures,
        SUM(CASE WHEN pl.ProcStatus = 6 THEN 1 ELSE 0 END) AS deleted_procedures,
        SUM(pl.ProcFee) AS total_fees,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN pl.ProcFee ELSE 0 END) AS completed_fees,
        SUM(pa.total_paid) AS total_payments,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN pa.total_paid ELSE 0 END) AS completed_payments,
        -- Calculate unpaid metrics
        SUM(CASE WHEN pl.ProcStatus = 2 AND pl.ProcFee > 0 AND pa.total_paid = 0 
            THEN 1 ELSE 0 END) AS unpaid_completed_count,
        SUM(CASE WHEN pl.ProcStatus = 2 AND pl.ProcFee > 0 AND pa.total_paid = 0 
            THEN pl.ProcFee ELSE 0 END) AS unpaid_completed_fees,
        -- Success rate
        SUM(CASE WHEN sc.is_successful THEN 1 ELSE 0 END) AS successful_procedures,
        ROUND(100.0 * SUM(CASE WHEN sc.is_successful THEN 1 ELSE 0 END) / 
               NULLIF(SUM(CASE WHEN pl.ProcStatus = 2 THEN 1 ELSE 0 END), 0), 2) AS success_rate
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    LEFT JOIN SuccessCriteria sc ON pl.ProcNum = sc.ProcNum
    GROUP BY proc_year, proc_month
)
SELECT
    proc_year,
    proc_month,
    total_procedures,
    completed_procedures,
    planned_procedures,
    deleted_procedures,
    ROUND(unpaid_completed_count * 100.0 / NULLIF(completed_procedures, 0), 2) AS percent_unpaid,
    unpaid_completed_count,
    unpaid_completed_fees,
    ROUND(total_fees, 2) AS total_fees,
    ROUND(completed_fees, 2) AS completed_fees,
    ROUND(total_payments, 2) AS total_payments,
    ROUND(completed_payments, 2) AS completed_payments,
    ROUND(completed_payments * 100.0 / NULLIF(completed_fees, 0), 2) AS payment_rate,
    success_rate
FROM MonthlyData
ORDER BY proc_year, proc_month;
