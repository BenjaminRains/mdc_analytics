-- Temporal Patterns Query
-- Analyzes procedures and payments across time
-- CTEs used: excluded_codes.sql, base_procedures.sql, payment_activity.sql, success_criteria.sql, monthly_data.sql
-- Date filter: 2024-01-01 to 2025-01-01
SELECT
    proc_year,
    proc_month,
    total_procedures,
    completed_procedures,
    planned_procedures,
    deleted_procedures,
    ROUND(unpaid_completed_count * 100.0 / NULLIF(completed_procedures, 0), 2) AS percent_unpaid,
    unpaid_completed_count,
    unpaid_completed_fees,
    ROUND(total_fees, 2) AS total_fees,
    ROUND(completed_fees, 2) AS completed_fees,
    ROUND(total_payments, 2) AS total_payments,
    ROUND(completed_payments, 2) AS completed_payments,
    ROUND(completed_payments * 100.0 / NULLIF(completed_fees, 0), 2) AS payment_rate,
    success_rate
FROM MonthlyData
WHERE proc_year >= '2024'
ORDER BY proc_year, proc_month;
