-- PROCEDURE APPOINTMENT SUMMARY
-- Combines procedures with their associated appointments and payments
-- Provides consolidated view of procedure execution and appointment information
-- dependent CTEs: BaseProcedures, PaymentActivity, AppointmentDetails, SuccessCriteria
ProcedureAppointmentSummary AS (
    SELECT
        bp.ProcNum,
        bp.PatNum,
        bp.ProcDate,
        bp.ProcStatus,
        bp.ProcFee,
        bp.AptNum,
        bp.DateComplete,
        bp.ProcCode,
        bp.Descript,
        bp.CodeCategory,
        pa.total_paid,
        pa.payment_ratio,
        ad.AptDateTime,
        ad.AptStatus,
        sc.is_successful
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN AppointmentDetails ad ON bp.AptNum = ad.AptNum
    LEFT JOIN SuccessCriteria sc ON bp.ProcNum = sc.ProcNum
)