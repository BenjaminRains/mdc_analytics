-- ProcedurePaymentJourney: Tracks the complete journey of procedures through insurance payment
-- Date filter: 2024-01-01 to 2025-01-01
-- Dependencies: none

ProcedurePaymentJourney AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProcDate,
        pl.ProcFee,
        pl.ProcStatus,
        pl.CodeNum,
        cp.ClaimNum,
        cp.PlanNum,
        cp.InsPayEst,
        cp.InsPayAmt,
        cp.WriteOff,
        cp.DedApplied,
        cp.Status as ClaimStatus,
        cp.DateCP as ClaimPaymentDate,
        cpt.ClaimPaymentNum,
        cpt.CheckNum,
        cpt.CheckAmt,
        ps.SplitNum,
        ps.SplitAmt,
        p.PayNum,
        p.PayDate,
        p.PayAmt as TotalPaymentAmount,
        -- BlueBook tracking
        ibb.InsPayAmt as BlueBookPayAmt,
        ibb.AllowedOverride as BlueBookAllowed,
        ibbl.AllowedFee as LoggedAllowedFee,
        -- Payment analysis
        COALESCE(cp.InsPayAmt, 0) + COALESCE(cp.WriteOff, 0) + COALESCE(cp.DedApplied, 0) as total_insurance_handled,
        pl.ProcFee - (COALESCE(cp.InsPayAmt, 0) + COALESCE(cp.WriteOff, 0) + COALESCE(cp.DedApplied, 0)) as remaining_patient_portion,
        CASE 
            WHEN cp.Status IN (1, 4, 5) THEN 'Paid'
            WHEN cp.Status = 6 THEN 'Rejected'
            WHEN cp.Status = 2 THEN 'Sent'
            WHEN cp.Status = 3 THEN 'Pending'
            ELSE 'Other'
        END as payment_status,
        DATEDIFF(COALESCE(cp.DateCP, CURRENT_DATE), pl.ProcDate) as days_to_payment,
        ROW_NUMBER() OVER (
            PARTITION BY pl.ProcNum 
            ORDER BY cp.DateCP DESC
        ) as claim_rank
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
    LEFT JOIN claimpayment cpt ON cp.ClaimPaymentNum = cpt.ClaimPaymentNum
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
    LEFT JOIN payment p ON ps.PayNum = p.PayNum
    LEFT JOIN insbluebook ibb ON pl.ProcNum = ibb.ProcNum
    LEFT JOIN insbluebooklog ibbl ON cp.ClaimProcNum = ibbl.ClaimProcNum
    WHERE pl.ProcDate BETWEEN '{{START_DATE}}' AND '{{END_DATE}}'
        AND pl.ProcStatus = 2 -- Complete
        AND (cp.ClaimNum IS NULL OR cp.Status != 7) -- Exclude reversed claims
) 