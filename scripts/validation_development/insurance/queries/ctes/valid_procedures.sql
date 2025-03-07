-- Get procedures with claims in date range
-- Date range: @start_date to @end_date
-- Dependencies:

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
)