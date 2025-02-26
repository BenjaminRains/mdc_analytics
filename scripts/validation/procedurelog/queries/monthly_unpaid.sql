-- Monthly Unpaid Procedures Query
-- Analyzes unpaid completed procedures by month to identify trends
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

UnpaidCompleted AS (
    SELECT 
        pl.ProcNum,
        pl.ProcDate,
        EXTRACT(MONTH FROM pl.ProcDate) AS proc_month,
        pl.ProcFee,
        pa.total_paid
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcStatus = 2 -- Completed
      AND pl.ProcFee > 0 -- Has a fee
      AND pl.CodeCategory = 'Standard' -- Not an excluded code
      AND (pa.total_paid IS NULL OR pa.total_paid = 0) -- No payments
)

SELECT 
    proc_month,
    COUNT(*) AS unpaid_count,
    SUM(ProcFee) AS unpaid_fees,
    ROUND(AVG(ProcFee), 2) AS avg_unpaid_fee,
    MIN(ProcFee) AS min_fee,
    MAX(ProcFee) AS max_fee,
    COUNT(DISTINCT CASE WHEN ProcFee >= 1000 THEN ProcNum ELSE NULL END) AS high_value_count
FROM UnpaidCompleted
GROUP BY proc_month
ORDER BY proc_month; 