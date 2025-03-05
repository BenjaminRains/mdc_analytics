-- InsuranceFeeSchedules: Links insurance plans with their fee schedules and actual fees
-- Date filter: @start_date to @end_date
-- Dependencies: none

InsuranceFeeSchedules AS (
    SELECT 
        ip.PlanNum,
        ip.CarrierNum,
        ip.FeeSched as PlanFeeSched,
        ip.AllowedFeeSched,
        ip.CopayFeeSched,
        fs.Description as FeeSchedDesc,
        fs.FeeSchedType,
        f.CodeNum,
        f.Amount as FeeAmount,
        f.UseDefaultFee,
        f.ClinicNum,
        COALESCE(fsg.Description, 'No Group') as FeeSchedGroupDesc,
        COUNT(DISTINCT cp.ClaimProcNum) as times_used_in_claims,
        AVG(CASE 
            WHEN cp.Status IN (1, 4, 5) -- Received statuses
            THEN cp.InsPayAmt / NULLIF(cp.FeeBilled, 0) 
            END) as avg_payment_ratio,
        SUM(CASE 
            WHEN cp.Status IN (1, 4, 5) 
            THEN cp.InsPayAmt 
            END) as total_payments,
        COUNT(DISTINCT CASE 
            WHEN cp.Status IN (1, 4, 5) 
            THEN cp.ClaimProcNum 
            END) as paid_claim_count
    FROM insplan ip
    JOIN feesched fs ON ip.FeeSched = fs.FeeSchedNum
    LEFT JOIN fee f ON fs.FeeSchedNum = f.FeeSched
    LEFT JOIN feeschedgroup fsg ON fs.FeeSchedNum = fsg.FeeSchedNum
    LEFT JOIN claimproc cp ON ip.PlanNum = cp.PlanNum
    LEFT JOIN procedurelog pl ON cp.ProcNum = pl.ProcNum 
        AND f.CodeNum = pl.CodeNum
        AND pl.ProcDate BETWEEN @start_date AND @end_date
    GROUP BY 
        ip.PlanNum,
        ip.CarrierNum,
        ip.FeeSched,
        ip.AllowedFeeSched,
        ip.CopayFeeSched,
        fs.Description,
        fs.FeeSchedType,
        f.CodeNum,
        f.Amount,
        f.UseDefaultFee,
        f.ClinicNum,
        COALESCE(fsg.Description, 'No Group')
)