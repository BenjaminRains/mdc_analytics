-- Status Transitions Query
-- Validates the status transitions of procedures and identifies potential issues
-- Dependent CTEs: excluded_codes.sql, base_procedures.sql, status_history.sql, transition_analysis.sql
-- Date filter: 2024-01-01 to 2025-01-01
SELECT
    status_description,
    transition_pattern,
    procedure_count,
    ROUND(100.0 * procedure_count / SUM(procedure_count) OVER (PARTITION BY status_description), 2) AS pct_of_status,
    with_fee_count,
    ROUND(100.0 * with_fee_count / procedure_count, 2) AS with_fee_pct,
    with_appointment,
    ROUND(100.0 * with_appointment / procedure_count, 2) AS with_appt_pct,
    min_days,
    avg_days,
    max_days,
    total_fees
FROM TransitionAnalysis
ORDER BY status_description, procedure_count DESC; 