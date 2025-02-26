-- Status Distribution Query
-- Analyzes the distribution of procedures by status code
-- CTEs used: excluded_codes.sql, base_procedures.sql, payment_activity.sql, success_criteria.sql, appointment_details.sql
-- Date filter: 2024-01-01 to 2025-01-01
SELECT
    pl.ProcStatus,
    CASE pl.ProcStatus
        WHEN 1 THEN 'Treatment Planned'
        WHEN 2 THEN 'Completed'
        WHEN 3 THEN 'Existing Current'
        WHEN 4 THEN 'Existing Other'
        WHEN 5 THEN 'Referred'
        WHEN 6 THEN 'Deleted'
        WHEN 7 THEN 'Condition'
        WHEN 8 THEN 'Invalid'
        ELSE 'Unknown'
    END AS status_description,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    COUNT(DISTINCT pl.PatNum) AS unique_patients,
    COUNT(DISTINCT pl.ProcCode) AS unique_codes,
    SUM(CASE WHEN pl.ProcFee = 0 THEN 1 ELSE 0 END) AS zero_fee_count,
    SUM(CASE WHEN pl.ProcFee > 0 THEN 1 ELSE 0 END) AS with_fee_count,
    ROUND(AVG(CASE WHEN pl.ProcFee > 0 THEN pl.ProcFee ELSE NULL END), 2) AS avg_fee,
    SUM(pl.ProcFee) AS total_fees,
    SUM(CASE WHEN pa.total_paid > 0 THEN 1 ELSE 0 END) AS with_payments,
    ROUND(100.0 * SUM(CASE WHEN pa.total_paid > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS payment_rate,
    SUM(pa.total_paid) AS total_paid,
    ROUND(SUM(pa.total_paid) / NULLIF(SUM(pl.ProcFee), 0) * 100, 2) AS collection_rate,
    COUNT(CASE WHEN sc.is_successful THEN 1 END) AS successful_count,
    ROUND(100.0 * COUNT(CASE WHEN sc.is_successful THEN 1 END) / COUNT(*), 2) AS success_rate
FROM BaseProcedures pl
LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
LEFT JOIN SuccessCriteria sc ON pl.ProcNum = sc.ProcNum
GROUP BY pl.ProcStatus
ORDER BY procedure_count DESC;
