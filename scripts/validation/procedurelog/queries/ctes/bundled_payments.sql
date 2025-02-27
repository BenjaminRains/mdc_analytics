-- BUNDLED PAYMENTS
-- Calculates payment data for visits with multiple procedures
-- Used for analyzing how bundled procedures are billed and paid
-- dependent CTEs: visit_counts.sql, base_procedures.sql, payment_activity.sql
BundledPayments AS (
    SELECT
        vc.PatNum,
        vc.ProcDate,
        vc.procedure_count,
        vc.total_fee,
        SUM(pa.total_paid) AS total_paid,
        SUM(pa.total_paid) / NULLIF(vc.total_fee, 0) AS payment_ratio,
        COUNT(CASE WHEN pa.total_paid > 0 THEN 1 END) AS procedures_with_payment,
        COUNT(CASE WHEN pa.total_paid = 0 THEN 1 END) AS procedures_without_payment
    FROM VisitCounts vc
    JOIN BaseProcedures bp 
         ON vc.PatNum   = bp.PatNum 
        AND vc.ProcDate = bp.ProcDate
    LEFT JOIN PaymentActivity pa 
          ON bp.ProcNum = pa.ProcNum
    GROUP BY vc.PatNum, vc.ProcDate, vc.procedure_count, vc.total_fee
)