-- Payment Metrics Query
-- Analyzes payment ratios and patterns for completed procedures

WITH
PaymentRatios AS (
    SELECT
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcFee,
        pa.total_paid,
        pa.payment_ratio,
        CASE
            WHEN pl.ProcFee = 0 THEN 'Zero Fee'
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 'No Payment'
            WHEN pa.payment_ratio >= 0.98 THEN '98-100%+'
            WHEN pa.payment_ratio >= 0.95 THEN '95-98%'
            WHEN pa.payment_ratio >= 0.90 THEN '90-95%'
            WHEN pa.payment_ratio >= 0.75 THEN '75-90%'
            WHEN pa.payment_ratio >= 0.50 THEN '50-75%'
            WHEN pa.payment_ratio > 0 THEN '1-50%'
            ELSE 'No Payment'
        END AS payment_category
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcStatus = 2  -- Completed procedures only
      AND pl.ProcFee > 0     -- Only procedures with fees
      AND pl.CodeCategory = 'Standard'  -- Exclude exempted codes
)

SELECT
    payment_category,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    MIN(payment_ratio) AS min_ratio,
    MAX(payment_ratio) AS max_ratio,
    ROUND(AVG(payment_ratio), 4) AS avg_ratio,
    SUM(ProcFee) AS total_fees,
    SUM(total_paid) AS total_paid,
    ROUND(SUM(total_paid) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS payment_percentage
FROM PaymentRatios
GROUP BY payment_category
ORDER BY 
    CASE payment_category
        WHEN 'Zero Fee' THEN 1
        WHEN '98-100%+' THEN 2
        WHEN '95-98%' THEN 3
        WHEN '90-95%' THEN 4
        WHEN '75-90%' THEN 5
        WHEN '50-75%' THEN 6
        WHEN '1-50%' THEN 7
        WHEN 'No Payment' THEN 8
        ELSE 9
    END;
