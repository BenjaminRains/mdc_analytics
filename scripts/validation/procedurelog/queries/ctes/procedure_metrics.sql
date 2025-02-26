-- PROCEDURE METRICS
-- Calculates key metrics about procedures including counts, status, fees, and payments
-- Used for dashboard metrics and summary reports
ProcedureMetrics AS (
    SELECT
        COUNT(*) AS total_procedures,
        SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_procedures,
        SUM(CASE WHEN ProcStatus = 1 THEN 1 ELSE 0 END) AS planned_procedures,
        SUM(CASE WHEN ProcStatus = 6 THEN 1 ELSE 0 END) AS deleted_procedures,
        SUM(CASE WHEN CodeCategory = 'Excluded' THEN 1 ELSE 0 END) AS excluded_procedures,
        SUM(CASE WHEN ProcFee = 0 THEN 1 ELSE 0 END) AS zero_fee_procedures,
        SUM(CASE WHEN ProcFee > 0 THEN 1 ELSE 0 END) AS with_fee_procedures,
        AVG(CASE WHEN ProcStatus = 2 AND ProcFee > 0 THEN payment_ratio ELSE NULL END) AS avg_payment_ratio_completed,
        SUM(CASE WHEN ProcStatus = 2 AND payment_ratio >= 0.95 THEN 1 ELSE 0 END) AS paid_95pct_plus_count,
        SUM(CASE WHEN is_successful THEN 1 ELSE 0 END) AS successful_procedures,
        ROUND(100.0 * SUM(CASE WHEN is_successful THEN 1 ELSE 0 END) / 
               NULLIF(SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END), 0), 2) AS success_rate_pct,
        SUM(ProcFee) AS total_fees,
        SUM(CASE WHEN ProcStatus = 2 THEN ProcFee ELSE 0 END) AS completed_fees,
        SUM(total_paid) AS total_payments,
        ROUND(SUM(total_paid) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS overall_payment_rate_pct
    FROM ProcedureAppointmentSummary
)