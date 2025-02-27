
-- Bundle Size Payment Analysis
-- Analyzes payment patterns for bundled procedures
-- Dependent CTEs: excluded_codes.sql, base_procedures.sql, payment_activity.sql, visit_counts.sql, bundled_payments.sql, payment_analysis.sql
SELECT
    bundle_size,
    visit_count,
    total_procedures,
    avg_procedures_per_visit,
    avg_visit_fee,
    total_fees,
    total_paid,
    payment_percentage,
    fully_paid_visits,
    fully_paid_pct
FROM PaymentAnalysis
ORDER BY
    CASE bundle_size
        WHEN 'Single Procedure' THEN 1
        WHEN '2-3 Procedures' THEN 2
        WHEN '4-5 Procedures' THEN 3
        WHEN '6+ Procedures' THEN 4
    END DESC;