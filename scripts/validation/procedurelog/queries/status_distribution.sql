-- Status Distribution Query
-- Analyzes the distribution of procedures by status code

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
    END AS StatusDescription,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    ROUND(AVG(pl.ProcFee), 2) AS avg_fee,
    SUM(pl.ProcFee) AS total_fees,
    COUNT(DISTINCT pl.PatNum) AS unique_patients,
    COUNT(DISTINCT pc.ProcCode) AS unique_codes,
    SUM(CASE WHEN pa.total_paid > 0 THEN 1 ELSE 0 END) AS with_payments,
    ROUND(100.0 * SUM(CASE WHEN pa.total_paid > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS payment_rate,
    SUM(pa.total_paid) AS total_paid,
    ROUND(SUM(pa.total_paid) / NULLIF(SUM(pl.ProcFee), 0) * 100, 2) AS collection_rate
FROM BaseProcedures pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
GROUP BY pl.ProcStatus
ORDER BY procedure_count DESC;
