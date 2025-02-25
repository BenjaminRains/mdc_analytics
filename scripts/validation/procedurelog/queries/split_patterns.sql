-- Split Patterns Query
-- Analyzes how payments are split between insurance and direct payments

WITH 
-- Define excluded codes that are exempt from payment validation
ExcludedCodes AS (
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
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2024-12-31' -- Fixed date range for testing
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

PaymentSplits AS (
    SELECT
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcFee,
        pa.insurance_paid,
        pa.direct_paid,
        pa.total_paid,
        CASE
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 'No Payment'
            WHEN pa.insurance_paid > 0 AND pa.direct_paid > 0 THEN 'Split Payment'
            WHEN pa.insurance_paid > 0 THEN 'Insurance Only'
            WHEN pa.direct_paid > 0 THEN 'Direct Payment Only'
            ELSE 'No Payment'
        END AS payment_type,
        CASE
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 0
            WHEN pa.total_paid > 0 THEN pa.insurance_paid / pa.total_paid
            ELSE 0
        END AS insurance_ratio
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcFee > 0  -- Only procedures with fees
)

SELECT
    payment_type,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    ROUND(AVG(ProcFee), 2) AS avg_fee,
    SUM(ProcFee) AS total_fees,
    SUM(total_paid) AS total_paid,
    ROUND(SUM(total_paid) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS payment_percentage,
    ROUND(AVG(CASE WHEN payment_type = 'Split Payment' THEN insurance_ratio ELSE NULL END), 4) AS avg_insurance_portion,
    ROUND(AVG(CASE WHEN total_paid > 0 THEN total_paid ELSE NULL END), 2) AS avg_payment_amount,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    ROUND(100.0 * SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS completed_pct
FROM PaymentSplits
GROUP BY payment_type
ORDER BY procedure_count DESC;
