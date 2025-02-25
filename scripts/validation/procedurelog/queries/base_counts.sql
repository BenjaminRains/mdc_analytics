-- Base Counts Query
-- Provides fundamental counts and statistics for procedures

-- Define excluded codes that are exempt from payment validation
WITH ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
      '~GRP~', 'D9987', 'D9986', 'Watch', 'Ztoth', 'D0350',
      '00040', 'D2919', '00051',
      'D9992', 'D9995', 'D9996',
      'D0190', 'D0171', 'D0140', 'D9430', 'D0120'
    )
),

-- Base procedure set (filtered by date range)
BaseProcedures AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProvNum,
        pl.ProcDate,
        pl.ProcStatus,
        pl.ProcFee,
        pl.CodeNum,
        pl.AptNum,
        pl.DateComplete,
        pc.ProcCode,
        pc.Descript,
        CASE WHEN ec.CodeNum IS NOT NULL THEN 'Excluded' ELSE 'Standard' END AS CodeCategory
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN ExcludedCodes ec ON pl.CodeNum = ec.CodeNum
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2024-12-31'  -- Fixed date range for testing
),

-- Payment information for procedures
PaymentActivity AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) AS direct_paid,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid,
        CASE 
            WHEN pl.ProcFee > 0 THEN 
                (COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0)) / pl.ProcFee 
            ELSE NULL 
        END AS payment_ratio
    FROM BaseProcedures pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    GROUP BY pl.ProcNum, pl.ProcFee
)

-- Base Counts Query
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
    SUM(CASE WHEN ProcStatus = 7 THEN 1 ELSE 0 END) AS `condition`,
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
