-- Edge Case Query
-- Identifies edge cases and anomalies in procedure payments
-- Dependent CTEs: excluded_codes.sql, base_procedures.sql, payment_activity.sql, edge_cases.sql
SELECT 
    edge_case_type,
    COUNT(*) AS case_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    COUNT(DISTINCT ProcCode) AS unique_codes,
    ROUND(AVG(ProcFee), 2) AS avg_fee,
    SUM(ProcFee) AS total_fees,
    SUM(total_paid) AS total_paid,
    ROUND(SUM(total_paid) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS payment_percentage
FROM EdgeCases
GROUP BY edge_case_type
ORDER BY case_count DESC;
