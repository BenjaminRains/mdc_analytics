-- EDGE CASES
-- Identifies payment anomalies and edge cases in procedure billing
-- Used for exception reporting and data quality analysis
-- Dependent CTEs: base_procedures.sql, payment_activity.sql
PaymentEdgeCases AS (
    SELECT
        bp.ProcNum,
        bp.PatNum,
        bp.ProcCode,
        bp.ProcDate,
        bp.ProcStatus,
        bp.ProcFee,
        pa.total_paid,
        pa.payment_ratio,
        CASE
            WHEN bp.ProcStatus = 2 AND bp.ProcFee = 0 THEN 'Completed zero-fee'
            WHEN bp.ProcStatus = 2 AND bp.ProcFee > 0 AND pa.total_paid = 0 THEN 'Completed unpaid'
            WHEN bp.ProcStatus = 2 AND pa.payment_ratio > 1.05 THEN 'Overpaid'
            WHEN bp.ProcStatus = 2 AND pa.payment_ratio BETWEEN 0.01 AND 0.50 THEN 'Significantly underpaid'
            WHEN bp.ProcStatus = 6 AND pa.total_paid > 0 THEN 'Deleted with payment'
            WHEN bp.ProcStatus = 1 AND pa.total_paid > 0 THEN 'Planned with payment'
            ELSE NULL
        END AS edge_case_type
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    WHERE 
        (bp.ProcStatus = 2 AND bp.ProcFee = 0) OR
        (bp.ProcStatus = 2 AND bp.ProcFee > 0 AND pa.total_paid = 0) OR
        (bp.ProcStatus = 2 AND pa.payment_ratio > 1.05) OR
        (bp.ProcStatus = 2 AND pa.payment_ratio BETWEEN 0.01 AND 0.50) OR
        (bp.ProcStatus = 6 AND pa.total_paid > 0) OR
        (bp.ProcStatus = 1 AND pa.total_paid > 0)
)