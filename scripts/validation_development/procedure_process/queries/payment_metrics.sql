-- Payment Metrics Query
-- Analyzes payment ratios and patterns for completed procedures
-- Dependent CTEs: excluded_codes.sql, base_procedures.sql, payment_activity.sql, payment_ratios.sql
-- Date filter: 2024-01-01 to 2025-01-01
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
