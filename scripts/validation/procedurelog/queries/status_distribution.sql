-- Status Distribution Query
-- Analyzes the distribution of procedures by status code

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
),

-- Success criteria evaluation
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
),

-- Appointment information
AppointmentDetails AS (
    SELECT
        a.AptNum,
        a.AptDateTime,
        a.AptStatus
    FROM appointment a
    WHERE a.AptDateTime >= '2024-01-01' AND a.AptDateTime < '2024-12-31'
)

-- Status Distribution Query
SELECT
    pl.ProcStatus,
    CASE pl.ProcStatus
        WHEN 1 THEN 'Treatment Planned'
        WHEN 2 THEN 'Completed'
        WHEN 3 THEN 'Existing Current'
        WHEN 4 THEN 'Existing Other'
        WHEN 5 THEN 'Referred'
        WHEN 6 THEN 'Deleted'
        WHEN 7 THEN 'Condition'
        WHEN 8 THEN 'Invalid'
        ELSE 'Unknown'
    END AS status_description,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    COUNT(DISTINCT pl.PatNum) AS unique_patients,
    COUNT(DISTINCT pl.ProcCode) AS unique_codes,
    SUM(CASE WHEN pl.ProcFee = 0 THEN 1 ELSE 0 END) AS zero_fee_count,
    SUM(CASE WHEN pl.ProcFee > 0 THEN 1 ELSE 0 END) AS with_fee_count,
    ROUND(AVG(CASE WHEN pl.ProcFee > 0 THEN pl.ProcFee ELSE NULL END), 2) AS avg_fee,
    SUM(pl.ProcFee) AS total_fees,
    SUM(CASE WHEN pa.total_paid > 0 THEN 1 ELSE 0 END) AS with_payments,
    ROUND(100.0 * SUM(CASE WHEN pa.total_paid > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS payment_rate,
    SUM(pa.total_paid) AS total_paid,
    ROUND(SUM(pa.total_paid) / NULLIF(SUM(pl.ProcFee), 0) * 100, 2) AS collection_rate,
    COUNT(CASE WHEN sc.is_successful THEN 1 END) AS successful_count,
    ROUND(100.0 * COUNT(CASE WHEN sc.is_successful THEN 1 END) / COUNT(*), 2) AS success_rate
FROM BaseProcedures pl
LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
LEFT JOIN SuccessCriteria sc ON pl.ProcNum = sc.ProcNum
GROUP BY pl.ProcStatus
ORDER BY procedure_count DESC;
