-- PAYMENT RATIOS
-- Categorizes procedures by payment percentage rates
-- Used for analyzing payment effectiveness and partial payment patterns
-- Dependent CTEs: base_procedures.sql, payment_activity.sql
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