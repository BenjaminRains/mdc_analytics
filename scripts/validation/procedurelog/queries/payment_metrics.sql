-- Payment Metrics Query
-- Analyzes payment ratios and patterns for completed procedures
-- CTEs used: ExcludedCodes, BaseProcedures, PaymentActivity

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

PaymentRatios AS (
    SELECT
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcFee,
        pa.total_paid,
        pa.payment_ratio,
        CASE
            WHEN pl.ProcFee = 0 THEN 'Zero Fee'
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 'No Payment'
            WHEN pa.payment_ratio >= 0.98 THEN '98-100%+'
            WHEN pa.payment_ratio >= 0.95 THEN '95-98%'
            WHEN pa.payment_ratio >= 0.90 THEN '90-95%'
            WHEN pa.payment_ratio >= 0.75 THEN '75-90%'
            WHEN pa.payment_ratio >= 0.50 THEN '50-75%'
            WHEN pa.payment_ratio > 0 THEN '1-50%'
            ELSE 'No Payment'
        END AS payment_category
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcStatus = 2  -- Completed procedures only
      AND pl.ProcFee > 0     -- Only procedures with fees
      AND pl.CodeCategory = 'Standard'  -- Exclude exempted codes
)

SELECT
    payment_category,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    MIN(payment_ratio) AS min_ratio,
    MAX(payment_ratio) AS max_ratio,
    ROUND(AVG(payment_ratio), 4) AS avg_ratio,
    SUM(ProcFee) AS total_fees,
    SUM(total_paid) AS total_paid,
    ROUND(SUM(total_paid) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS payment_percentage
FROM PaymentRatios
GROUP BY payment_category
ORDER BY 
    CASE payment_category
        WHEN 'Zero Fee' THEN 1
        WHEN '98-100%+' THEN 2
        WHEN '95-98%' THEN 3
        WHEN '90-95%' THEN 4
        WHEN '75-90%' THEN 5
        WHEN '50-75%' THEN 6
        WHEN '1-50%' THEN 7
        WHEN 'No Payment' THEN 8
        ELSE 9
    END;
