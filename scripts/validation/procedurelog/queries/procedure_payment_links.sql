-- Procedure Payment Links Query
-- Validates the relationships between procedures and their associated payments
-- Dependent CTEs: excluded_codes.sql, base_procedures.sql, payment_activity.sql, payment_links.sql, linkage_patterns.sql
-- Date filter: 2024-01-01 to 2025-01-01
SELECT
    payment_source_type,
    payment_status,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_of_total,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    ROUND(100.0 * SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS completed_pct,
    ROUND(AVG(paysplit_count), 2) AS avg_paysplit_count,
    ROUND(AVG(claimproc_count), 2) AS avg_claimproc_count,
    SUM(ProcFee) AS total_fee,
    SUM(direct_payment_amount) AS total_direct_payment,
    SUM(insurance_payment_amount) AS total_insurance_payment,
    SUM(direct_payment_amount + insurance_payment_amount) AS total_payment,
    ROUND(SUM(direct_payment_amount + insurance_payment_amount) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS payment_rate,
    SUM(CASE WHEN has_zero_insurance_payment = 1 THEN 1 ELSE 0 END) AS procs_with_zero_insurance,
    ROUND(AVG(CASE WHEN min_days_to_payment IS NOT NULL THEN min_days_to_payment ELSE NULL END)) AS avg_days_to_payment
FROM LinkagePatterns
GROUP BY payment_source_type, payment_status
ORDER BY payment_source_type, payment_status; 