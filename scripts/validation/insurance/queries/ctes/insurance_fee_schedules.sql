-- InsuranceFeeSchedules: Links insurance plans with their fee schedules and actual fees
-- Date filter: 2024-01-01 to 2025-01-01
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
        AND f.CodeNum = cp.CodeNum
        AND cp.ProcDate BETWEEN '{{START_DATE}}' AND '{{END_DATE}}'
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