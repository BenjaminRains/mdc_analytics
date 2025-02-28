-- Description: Carrier-level statistics for payments, claims, and procedures
-- Date range: 2024-01-01 to 2025-01-01
-- Dependent CTEs: valid_carriers.sql, plan_stats.sql

CarrierStats AS (
    SELECT 
        vc.CarrierName as OriginalCarrierName,
        vc.ElectID,
        SUM(ps.ProcCount) as TotalProcedures,
        SUM(ps.ClaimCount) as TotalClaims,
        SUM(ps.PaidClaimCount) as PaidClaims,
        SUM(ps.TotalBilled) as TotalBilled,
        SUM(ps.TotalPayments) as TotalPayments,
        SUM(ps.TotalWriteoffs) as TotalWriteoffs,
        SUM(ps.TotalDeductibles) as TotalDeductibles,
        AVG(ps.AvgDaysToPayment) as AvgDaysToPayment,
        AVG(ps.AvgPaymentRatio) as AvgPaymentRatio,
        -- Calculate percentages
        SUM(ps.TotalWriteoffs) * 100.0 / NULLIF(SUM(ps.TotalBilled), 0) as WriteOffPercent,
        SUM(ps.TotalPayments) * 100.0 / NULLIF(SUM(ps.TotalBilled), 0) as PaymentPercent,
        SUM(ps.TotalDeductibles) * 100.0 / NULLIF(SUM(ps.TotalBilled), 0) as DeductiblePercent,
        -- Calculate rejection rate
        (1 - (SUM(ps.PaidClaimCount) * 1.0 / NULLIF(SUM(ps.ClaimCount), 0))) * 100 as RejectionRate
    FROM ValidCarriers vc
    LEFT JOIN insplan ip ON vc.CarrierNum = ip.CarrierNum
    LEFT JOIN PlanStats ps ON ip.PlanNum = ps.PlanNum
    GROUP BY 
        vc.CarrierName,
        vc.ElectID
    HAVING SUM(ps.ProcCount) > 0
)