-- Pre-aggregate by plan
-- Date range: @start_date to @end_date
-- Dependencies: valid_procedures.sql

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
)