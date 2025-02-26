-- PaymentAnalysis CTE
-- Purpose: Analyzes payment patterns and statistics grouped by procedure bundle size
-- Calculates visit counts, procedure totals, and average procedures per visit
-- Computes financial metrics including fees, payments, and payment completion rates
-- Identifies fully paid visits (defined as >= 95% payment ratio)
-- Used for: Financial reporting and identifying payment patterns based on bundle complexity
-- dependent CTEs: BundledPayments
PaymentAnalysis AS (
    SELECT 
        bundle_size,
        COUNT(*) AS visit_count,
        SUM(procedure_count) AS total_procedures,
        ROUND(AVG(procedure_count), 2) AS avg_procedures_per_visit,
        ROUND(AVG(total_fee), 2) AS avg_visit_fee,
        SUM(total_fee) AS total_fees,
        SUM(total_paid) AS total_paid,
        ROUND(SUM(total_paid) / NULLIF(SUM(total_fee), 0) * 100, 2) AS payment_percentage,
        COUNT(CASE WHEN payment_ratio >= 0.95 THEN 1 END) AS fully_paid_visits,
        ROUND(COUNT(CASE WHEN payment_ratio >= 0.95 THEN 1 END) * 100.0 / COUNT(*), 2) AS fully_paid_pct
    FROM BundledPayments
    GROUP BY bundle_size
)