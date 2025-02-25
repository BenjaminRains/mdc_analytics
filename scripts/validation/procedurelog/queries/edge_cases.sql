-- Edge Case Query
-- Identifies edge cases and anomalies in procedure payments

WITH 
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
