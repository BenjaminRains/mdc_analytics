-- Appointment Overlap Query
-- Analyzes the relationship between procedures and appointments

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
            WHEN ad.AptStatus = 1 THEN 'Scheduled'
            WHEN ad.AptStatus = 2 THEN 'Complete'
            WHEN ad.AptStatus = 3 THEN 'UnschedList'
            WHEN ad.AptStatus = 4 THEN 'ASAP'
            WHEN ad.AptStatus = 5 THEN 'Broken'
            WHEN ad.AptStatus = 6 THEN 'Planned'
            WHEN ad.AptStatus = 7 THEN 'PtNote'
            WHEN ad.AptStatus = 8 THEN 'PtNoteCompleted'
            ELSE 'Unknown'
        END AS appointment_status
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN AppointmentDetails ad ON bp.AptNum = ad.AptNum
) AS combined_data
GROUP BY appointment_status
ORDER BY procedure_count DESC;
