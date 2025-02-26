-- Base Counts Query
-- Provides fundamental counts and statistics for procedures
-- CTEs used: excluded_codes.sql, base_procedures.sql, payment_activity.sql
-- Date filter: 2024-01-01 to 2025-01-01
SELECT
    -- Basic counts
    COUNT(*) AS total_procedures,
    COUNT(DISTINCT PatNum) AS unique_patients,
    COUNT(DISTINCT ProcCode) AS unique_procedure_codes,
    COUNT(DISTINCT AptNum) AS unique_appointments,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT PatNum), 2) AS procedures_per_patient,
    
    -- Status counts
    SUM(CASE WHEN ProcStatus = 1 THEN 1 ELSE 0 END) AS treatment_planned,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN ProcStatus = 3 THEN 1 ELSE 0 END) AS existing_current,
    SUM(CASE WHEN ProcStatus = 4 THEN 1 ELSE 0 END) AS existing_other,
    SUM(CASE WHEN ProcStatus = 5 THEN 1 ELSE 0 END) AS referred,
    SUM(CASE WHEN ProcStatus = 6 THEN 1 ELSE 0 END) AS deleted,
    SUM(CASE WHEN ProcStatus = 7 THEN 1 ELSE 0 END) AS need_to_do,
    SUM(CASE WHEN ProcStatus = 8 THEN 1 ELSE 0 END) AS invalid,
    
    -- Fee statistics
    SUM(CASE WHEN ProcFee = 0 THEN 1 ELSE 0 END) AS zero_fee_count,
    SUM(CASE WHEN ProcFee > 0 THEN 1 ELSE 0 END) AS with_fee_count,
    MIN(CASE WHEN ProcFee > 0 THEN ProcFee END) AS min_fee,
    MAX(ProcFee) AS max_fee,
    ROUND(AVG(CASE WHEN ProcFee > 0 THEN ProcFee END), 2) AS avg_fee,
    -- Using AVG instead of PERCENTILE_CONT for MariaDB compatibility
    'Calculate outside SQL' AS median_fee_note,
    
    -- Payment statistics
    COUNT(DISTINCT CASE WHEN total_paid > 0 THEN ProcNum END) AS procedures_with_payment,
    ROUND(COUNT(DISTINCT CASE WHEN total_paid > 0 THEN ProcNum END) * 100.0 / COUNT(*), 2) AS payment_rate,
    SUM(total_paid) AS total_payments,
    SUM(CASE WHEN ProcStatus = 2 THEN total_paid ELSE 0 END) AS completed_payments
FROM (
    SELECT bp.*, pa.total_paid
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
) AS combined_data;
