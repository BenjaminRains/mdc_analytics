-- PROCEDURE METRICS
-- Calculates key metrics about procedures including counts, status, fees, and payments
-- Used for dashboard metrics and summary reports
-- dependent CTEs: ProcedureAppointmentSummary
ProcedureMetrics AS (
    SELECT
        COUNT(*) AS total_procedures,
        SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_procedures,
        SUM(CASE WHEN ProcStatus = 1 THEN 1 ELSE 0 END) AS planned_procedures,
        SUM(CASE WHEN ProcStatus = 6 THEN 1 ELSE 0 END) AS CondPlanned_procedures, --A condition-based procedure is planned
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

""" FIXME:
### ProcStatus Codes
The `ProcStatus` field uses the following values:
1. **Treatment Planned**: Procedure is planned but not yet performed (20.37% of procedures)
2. **Completed**: Procedure has been performed and completed (51.68% of procedures)
3. **In Progress**: Procedure is currently being performed (6.00% of procedures)
4. **Deleted**: Existing condition that is not currently relevant (0.48% of procedures)
5. **Rejected**: Procedure was rejected (1.71% of procedures)
6. **CondPlanned**: A condition-based procedure is planned (15.83% of procedures)
7. **NeedToDo**: Procedure requires further action (3.88% of procedures)
8. **Invalid**: Invalid or erroneous procedure entry (0.05% of procedures)
"""