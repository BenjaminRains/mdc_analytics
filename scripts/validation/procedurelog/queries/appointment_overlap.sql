-- Appointment Overlap Query
-- Analyzes the relationship between procedures and appointments
-- CTEs used: ExcludedCodes, BaseProcedures, PaymentActivity, AppointmentDetails, AppointmentStatusCategories
SELECT
    appointment_status,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    ROUND(100.0 * SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS completed_rate,
    SUM(CASE WHEN ProcFee > 0 THEN 1 ELSE 0 END) AS with_fee_count,
    SUM(ProcFee) AS total_fees,
    SUM(total_paid) AS total_paid,
    ROUND(SUM(total_paid) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS payment_percentage,
    ROUND(AVG(CASE WHEN ProcFee > 0 THEN ProcFee END), 2) AS avg_fee,
    COUNT(DISTINCT PatNum) AS unique_patients
FROM (
    SELECT
        bp.*,
        pa.total_paid,
        CASE
            WHEN bp.AptNum IS NULL THEN 'No Appointment'
            ELSE ast.StatusDescription
        END AS appointment_status
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN AppointmentDetails ad ON bp.AptNum = ad.AptNum
    LEFT JOIN AppointmentStatusCategories ast ON ad.AptStatus = ast.AptStatus
) AS combined_data
GROUP BY appointment_status
ORDER BY procedure_count DESC;