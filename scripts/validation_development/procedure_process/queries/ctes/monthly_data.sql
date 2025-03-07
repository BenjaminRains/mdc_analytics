-- Monthly data aggregation
-- =======================
-- Purpose:
--     Aggregates procedure-related metrics on a monthly basis to track performance trends
--     and financial outcomes over time.
--
-- Metrics Calculated:
--     1. Volume Metrics
--        - Total procedures per month
--        - Breakdown by status (completed, planned, deleted)
--     
--     2. Financial Metrics
--        - Total procedure fees
--        - Completed procedure fees
--        - Total payments received
--        - Payments for completed procedures
--        - Unpaid completed procedures (count and fees)
--     
--     3. Quality Metrics
--        - Success rate of completed procedures
--        
-- Usage Examples:
--     - Track month-over-month procedure volume trends
--     - Monitor payment collection rates
--     - Analyze procedure success rates
--     - Identify seasonal patterns in procedure volume
--     - Track revenue trends and unpaid procedure backlog
--
-- Dependent CTEs: base_procedures.sql, payment_activity.sql, success_criteria.sql
MonthlyData AS (
    SELECT 
        EXTRACT(YEAR FROM pl.ProcDate) AS proc_year,
        EXTRACT(MONTH FROM pl.ProcDate) AS proc_month,
        -- Volume metrics
        COUNT(*) AS total_procedures,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_procedures,
        SUM(CASE WHEN pl.ProcStatus = 1 THEN 1 ELSE 0 END) AS planned_procedures,
        SUM(CASE WHEN pl.ProcStatus = 6 THEN 1 ELSE 0 END) AS deleted_procedures,
        
        -- Financial metrics
        SUM(pl.ProcFee) AS total_fees,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN pl.ProcFee ELSE 0 END) AS completed_fees,
        SUM(pa.total_paid) AS total_payments,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN pa.total_paid ELSE 0 END) AS completed_payments,
        
        -- Unpaid procedure metrics
        SUM(CASE WHEN pl.ProcStatus = 2 AND pl.ProcFee > 0 AND pa.total_paid = 0 
            THEN 1 ELSE 0 END) AS unpaid_completed_count,
        SUM(CASE WHEN pl.ProcStatus = 2 AND pl.ProcFee > 0 AND pa.total_paid = 0 
            THEN pl.ProcFee ELSE 0 END) AS unpaid_completed_fees,
        
        -- Success rate calculation
        SUM(CASE WHEN sc.is_successful THEN 1 ELSE 0 END) AS successful_procedures,
        ROUND(100.0 * SUM(CASE WHEN sc.is_successful THEN 1 ELSE 0 END) / 
               NULLIF(SUM(CASE WHEN pl.ProcStatus = 2 THEN 1 ELSE 0 END), 0), 2) AS success_rate
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    LEFT JOIN SuccessCriteria sc ON pl.ProcNum = sc.ProcNum
    GROUP BY proc_year, proc_month
)