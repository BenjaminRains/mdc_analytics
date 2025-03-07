-- SUCCESS CRITERIA
-- Evaluates business success criteria based on procedure status, fee, and payment
-- A procedure is considered successful if:
-- 1. It's completed with zero fee (for standard procedures), OR
-- 2. It's completed with fee and has received at least 95% payment
-- Dependent CTEs: base_procedures.sql, payment_activity.sql
SuccessCriteria AS (
    SELECT
        bp.ProcNum,
        bp.ProcStatus,
        bp.ProcFee,
        bp.CodeCategory,
        pa.total_paid,
        pa.payment_ratio,
        CASE
            -- Case 1: Completed procedure with zero fee (not excluded)
            WHEN bp.ProcStatus = 2 AND bp.ProcFee = 0 AND bp.CodeCategory = 'Standard' THEN TRUE
            -- Case 2: Completed procedure with fee >= 95% paid
            WHEN bp.ProcStatus = 2 AND bp.ProcFee > 0 AND pa.payment_ratio >= 0.95 THEN TRUE
            -- All other cases are not successful
            ELSE FALSE
        END AS is_successful
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
)