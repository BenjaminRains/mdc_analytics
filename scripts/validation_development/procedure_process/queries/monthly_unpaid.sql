-- Monthly Unpaid Procedures Query
-- Analyzes unpaid completed procedures by month to identify trends
-- Dependent CTEs: excluded_codes.sql, base_procedures.sql, payment_activity.sql, unpaid_completed.sql
-- Date filter: 2024-01-01 to 2025-01-01
SELECT 
    proc_month,
    COUNT(*) AS unpaid_count,
    SUM(ProcFee) AS unpaid_fees,
    ROUND(AVG(ProcFee), 2) AS avg_unpaid_fee,
    MIN(ProcFee) AS min_fee,
    MAX(ProcFee) AS max_fee,
    COUNT(DISTINCT CASE WHEN ProcFee >= 1000 THEN ProcNum ELSE NULL END) AS high_value_count
FROM UnpaidCompleted
GROUP BY proc_month
ORDER BY proc_month; 