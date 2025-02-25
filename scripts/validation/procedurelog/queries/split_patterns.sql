-- Split Patterns Query
-- Analyzes how payments are split between insurance and direct payments

WITH
PaymentSplits AS (
    SELECT
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcFee,
        pa.insurance_paid,
        pa.direct_paid,
        pa.total_paid,
        CASE
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 'No Payment'
            WHEN pa.insurance_paid > 0 AND pa.direct_paid > 0 THEN 'Split Payment'
            WHEN pa.insurance_paid > 0 THEN 'Insurance Only'
            WHEN pa.direct_paid > 0 THEN 'Direct Payment Only'
            ELSE 'No Payment'
        END AS payment_type,
        CASE
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 0
            WHEN pa.total_paid > 0 THEN pa.insurance_paid / pa.total_paid
            ELSE 0
        END AS insurance_ratio
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcFee > 0  -- Only procedures with fees
)

SELECT
    payment_type,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    ROUND(AVG(ProcFee), 2) AS avg_fee,
    SUM(ProcFee) AS total_fees,
    SUM(total_paid) AS total_paid,
    ROUND(SUM(total_paid) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS payment_percentage,
    ROUND(AVG(CASE WHEN payment_type = 'Split Payment' THEN insurance_ratio ELSE NULL END), 4) AS avg_insurance_portion,
    ROUND(AVG(CASE WHEN total_paid > 0 THEN total_paid ELSE NULL END), 2) AS avg_payment_amount,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    ROUND(100.0 * SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS completed_pct
FROM PaymentSplits
GROUP BY payment_type
ORDER BY procedure_count DESC;
