-- Split Patterns Query
-- Analyzes how payments are split between insurance and direct payments
-- Dependent CTEs: excluded_codes.sql, base_procedures.sql, payment_activity.sql, payment_splits.sql
-- Date filter: 2024-01-01 to 2024-12-31
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
