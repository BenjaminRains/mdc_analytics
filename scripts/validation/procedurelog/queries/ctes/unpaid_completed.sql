-- UNPAID COMPLETED
-- Identifies completed procedures with no payments
-- Used for accounts receivable analysis and collection targeting
-- 
UnpaidCompleted AS (
    SELECT
        bp.ProcNum,
        bp.PatNum,
        bp.ProcDate,
        bp.DateComplete,
        bp.ProcStatus,
        bp.ProcCode,
        bp.Descript,
        bp.ProcFee,
        bp.CodeCategory,
        DATEDIFF(CURRENT_DATE, bp.DateComplete) AS days_since_completion
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    WHERE bp.ProcStatus = 2  -- Completed
      AND bp.ProcFee > 0     -- Has a fee
      AND (pa.total_paid IS NULL OR pa.total_paid = 0)  -- No payment
      AND bp.CodeCategory = 'Standard'  -- Not excluded
)