/*
 * Optimized Carrier Payment Analysis
 * 
 * Changes from original:
 * 1. Split complex CTEs into smaller, focused parts
 * 2. Early filtering to reduce data volume
 * 3. Optimized join conditions
 * 4. Pre-aggregated calculations
 * 5. Simplified median calculation
 */

WITH DateRange AS (
    SELECT 
        '2024-01-01' as start_date,
        '2025-01-01' as end_date
),
-- First get valid carriers and plans
ValidCarriers AS (
    SELECT 
        c.CarrierNum,
        c.CarrierName,
        c.ElectID,
        COUNT(DISTINCT ip.PlanNum) as PlanCount
    FROM carrier c
    INNER JOIN insplan ip ON c.CarrierNum = ip.CarrierNum
    WHERE NOT c.IsHidden
    GROUP BY c.CarrierNum, c.CarrierName, c.ElectID
),
-- Get procedures with claims in date range
ValidProcedures AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProcDate,
        pl.ProcFee,
        pl.CodeNum,
        cp.PlanNum,
        cp.ClaimNum,
        cp.InsPayEst,
        cp.InsPayAmt,
        cp.WriteOff,
        cp.DedApplied,
        cp.Status as ClaimStatus,
        cp.DateCP as ClaimPaymentDate,
        CASE 
            WHEN cp.DateCP IS NOT NULL 
            AND DATEDIFF(cp.DateCP, pl.ProcDate) BETWEEN 0 AND 365
            THEN DATEDIFF(cp.DateCP, pl.ProcDate)
        END as days_to_payment
    FROM procedurelog pl 
    FORCE INDEX (idx_ml_proc_core)
    INNER JOIN claimproc cp 
    FORCE INDEX (idx_ml_claimproc_core)
    ON pl.ProcNum = cp.ProcNum
    INNER JOIN insplan ip 
    ON cp.PlanNum = ip.PlanNum
    INNER JOIN ValidCarriers vc 
    ON ip.CarrierNum = vc.CarrierNum
    CROSS JOIN DateRange d
    WHERE pl.ProcDate BETWEEN d.start_date AND d.end_date
        AND pl.ProcStatus = 2  -- Complete
        AND pl.ProcFee > 0     -- Only procedures with fees
        AND cp.Status != 7     -- Exclude reversed claims
),
-- Pre-aggregate by plan
PlanStats AS (
    SELECT 
        vp.PlanNum,
        COUNT(DISTINCT vp.ProcNum) as ProcCount,
        COUNT(DISTINCT vp.ClaimNum) as ClaimCount,
        COUNT(DISTINCT CASE 
            WHEN vp.ClaimStatus IN (1, 4, 5) 
            THEN vp.ClaimNum 
        END) as PaidClaimCount,
        SUM(vp.ProcFee) as TotalBilled,
        SUM(vp.InsPayAmt) as TotalPayments,
        SUM(vp.WriteOff) as TotalWriteoffs,
        SUM(vp.DedApplied) as TotalDeductibles,
        AVG(vp.days_to_payment) as AvgDaysToPayment,
        AVG(vp.InsPayAmt / NULLIF(vp.ProcFee, 0)) * 100 as AvgPaymentRatio
    FROM ValidProcedures vp
    GROUP BY vp.PlanNum
),
-- Final carrier aggregation
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