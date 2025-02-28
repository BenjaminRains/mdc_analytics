-- Description: Optimized carrier payment analysis with CTEs
-- Date range: 2024-01-01 to 2025-01-01
-- Dependent CTEs: date_range.sql, valid_carriers.sql, valid_procedures.sql, plan_stats.sql, carrier_stats.sql

SELECT 
    cs.OriginalCarrierName as CarrierName,
    cs.ElectID,
    cs.TotalProcedures,
    cs.TotalClaims,
    cs.PaidClaims,
    ROUND(cs.TotalBilled, 2) as TotalBilled,
    ROUND(cs.TotalPayments, 2) as TotalPayments,
    ROUND(cs.TotalWriteoffs, 2) as TotalWriteoffs,
    ROUND(cs.TotalDeductibles, 2) as TotalDeductibles,
    ROUND(cs.AvgPaymentRatio, 1) as AvgPaymentRatio,
    ROUND(cs.AvgDaysToPayment, 1) as AvgDaysToPayment,
    ROUND(cs.RejectionRate, 2) as RejectionRate,
    ROUND(cs.WriteOffPercent, 2) as WriteOffPercent,
    ROUND(cs.PaymentPercent, 2) as PaymentPercent,
    ROUND(cs.DeductiblePercent, 2) as DeductiblePercent
FROM CarrierStats cs
ORDER BY 
    cs.TotalPayments DESC,
    cs.OriginalCarrierName
LIMIT 200; 