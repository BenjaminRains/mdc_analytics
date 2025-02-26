-- Edge Case Query
-- Identifies edge cases and anomalies in procedure payments
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

EdgeCases AS (
    SELECT 
      pl.ProcNum,
      pl.PatNum,
      pl.ProcDate,
      pc.ProcCode,
      pc.Descript,
      pl.ProcStatus,
      pl.ProcFee,
      COALESCE(pa.total_paid, 0) AS total_paid,
      pa.payment_ratio,
      CASE 
        WHEN pl.ProcFee = 0 AND COALESCE(pa.total_paid, 0) > 0 THEN 'Zero_fee_payment'
        WHEN pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) > pl.ProcFee * 1.05 THEN 'Significant_overpayment'
        WHEN pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) > pl.ProcFee THEN 'Minor_overpayment'
        WHEN pl.ProcStatus = 2 AND pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) = 0 THEN 'Completed_unpaid'
        WHEN pl.ProcStatus = 2 AND pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / pl.ProcFee < 0.50 THEN 'Completed_underpaid'
        WHEN pl.ProcStatus != 2 AND COALESCE(pa.total_paid, 0) > 0 THEN 'Non_completed_with_payment'
        ELSE 'Normal'
      END AS edge_case_type
    FROM BaseProcedures pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
)

SELECT 
    edge_case_type,
    COUNT(*) AS case_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    COUNT(DISTINCT ProcCode) AS unique_codes,
    ROUND(AVG(ProcFee), 2) AS avg_fee,
    SUM(ProcFee) AS total_fees,
    SUM(total_paid) AS total_paid,
    ROUND(SUM(total_paid) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS payment_percentage
FROM EdgeCases
GROUP BY edge_case_type
ORDER BY case_count DESC;
