-- Treatment Journey Dataset Query
-- This query generates features and target variables for predicting treatment outcomes
-- Last updated: 2025-01-31

-- Main query for treatment journey dataset
SELECT 
    -- Identifiers and Dates
    proc.ProcNum,
    proc.ProcDate,
    proc.DateTP as PlanDate,
    
    -- Patient Features
    proc.PatNum,
    CASE 
        WHEN pat.Birthdate = '0001-01-01' THEN NULL
        WHEN pat.Birthdate > proc.ProcDate THEN NULL
        ELSE TIMESTAMPDIFF(YEAR, pat.Birthdate, proc.ProcDate) 
    END as PatientAge,
    pat.Gender,
    CASE WHEN pat.HasIns != '' THEN 1 ELSE 0 END as HasInsurance,

    -- Fee Schedule Features
    fs.Description as FeeScheduleType,
    CASE 
        WHEN f.Amount IS NULL THEN proc.ProcFee
        ELSE f.Amount 
    END as StandardFee,
    CASE 
        WHEN proc.ProcFee = f.Amount THEN 1
        WHEN f.Amount IS NULL THEN NULL
        ELSE proc.ProcFee / f.Amount 
    END as FeeRatio,
    
    -- Insurance Features (NEW)
    CASE 
        WHEN cp.Status = 1 THEN cp.InsPayEst  -- Received
        WHEN cp.Status = 0 THEN cp.InsPayEst  -- Not received
        ELSE 0 
    END as EstimatedInsurancePayment,
    
    COALESCE(cp.InsPayAmt, 0) as ActualInsurancePayment,
    
    CASE 
        WHEN cp.InsPayEst > 0 THEN 
            (cp.InsPayAmt / cp.InsPayEst) * 100
        ELSE NULL 
    END as InsurancePaymentAccuracy,
    
    -- Claim Status Features (NEW)
    CASE 
        WHEN c.ClaimStatus = 'S' THEN 'Sent'
        WHEN c.ClaimStatus = 'R' THEN 'Received'
        WHEN c.ClaimStatus = 'P' THEN 'Pending'
        ELSE 'Other'
    END as ClaimStatus,
    
    CASE 
        WHEN c.DateSent != '0001-01-01' THEN 1 
        ELSE 0 
    END as ClaimSubmitted,
    
    CASE 
        WHEN c.DateReceived != '0001-01-01' AND c.DateSent != '0001-01-01'
        THEN DATEDIFF(c.DateReceived, c.DateSent)
        ELSE NULL 
    END as DaysToClaimResponse,
    
    -- Insurance Processing Features (NEW)
    CASE 
        WHEN cp.Status = 1 AND c.DateReceived != '0001-01-01' 
        THEN DATEDIFF(cp.DateCP, c.DateReceived)
        ELSE NULL 
    END as DaysToPaymentAfterReceipt,
    
    -- Historical Insurance Features (NEW)
    COALESCE((
        SELECT AVG(cp2.InsPayAmt / cp2.InsPayEst) * 100
        FROM claimproc cp2
        WHERE cp2.PatNum = proc.PatNum
        AND cp2.ProcDate < proc.ProcDate
        AND cp2.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
        AND cp2.InsPayEst > 0
        AND cp2.Status = 1
    ), NULL) as Historical_Insurance_Payment_Accuracy,
    
    -- Insurance Claim Payment Features (NEW)
    COALESCE(cpy.CheckAmt, 0) as InsuranceCheckAmount,
    CASE 
        WHEN cpy.IsPartial = 1 THEN 'Partial'
        WHEN cpy.ClaimPaymentNum IS NOT NULL THEN 'Full'
        ELSE 'None'
    END as PaymentCompleteness,
    
    -- Payment Pattern Features
    COALESCE((
        SELECT AVG(DATEDIFF(pay.PayDate, p2.ProcDate))
        FROM procedurelog p2
        JOIN paysplit ps2 ON p2.ProcNum = ps2.ProcNum
        JOIN payment pay ON ps2.PayNum = pay.PayNum
        WHERE p2.PatNum = proc.PatNum
        AND p2.ProcDate < proc.ProcDate
        AND p2.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
    ), NULL) as Avg_Days_To_Payment,
    
    -- Fee Schedule Context
    CASE 
        WHEN fs.FeeSchedType = 1 THEN 'Standard'
        WHEN fs.FeeSchedType = 2 THEN 'Insurance'
        WHEN fs.FeeSchedType = 3 THEN 'Sliding Scale'
        ELSE 'Other'
    END as FeeScheduleCategory,
    
    -- Procedure Features
    pc.ProcCat,
    pc.ProcCode,
    pc.Descript as ProcDescript,
    pc.TreatArea,
    proc.ProcFee as PlannedFee,
    CASE WHEN pc.IsMultiVisit = 1 THEN 1 ELSE 0 END as IsMultiVisit,
    
    -- Temporal Features
    DAYOFWEEK(proc.ProcDate) as DayOfWeek,
    MONTH(proc.ProcDate) as Month,
    
    -- Target Variables
    CASE WHEN proc.ProcStatus = 2 THEN 1 ELSE 0 END as target_accepted,
    
    -- Payment Target Variables (Modified to exclude zero fees)
    CASE 
        WHEN proc.ProcFee <= 0 THEN NULL  -- Exclude zero/negative fees
        WHEN proc.ProcFee <= COALESCE(
            (SELECT SUM(ps.SplitAmt) FROM paysplit ps WHERE ps.ProcNum = proc.ProcNum), 0
        ) + COALESCE(cp.InsPayAmt, 0) + COALESCE(
            (SELECT SUM(adj.AdjAmt) FROM adjustment adj WHERE adj.ProcNum = proc.ProcNum), 0
        ) THEN 1 
        ELSE 0 
    END as target_fully_paid,
    
    CASE 
        WHEN proc.ProcFee <= 0 THEN NULL  -- Exclude zero/negative fees
        WHEN EXISTS (
            SELECT 1 
            FROM paysplit ps 
            JOIN payment pay ON ps.PayNum = pay.PayNum
            WHERE ps.ProcNum = proc.ProcNum 
            AND DATEDIFF(pay.PayDate, proc.ProcDate) <= 30
        ) OR EXISTS (
            SELECT 1
            FROM claimproc cp2
            WHERE cp2.ProcNum = proc.ProcNum
            AND cp2.Status = 1  -- Received
            AND DATEDIFF(cp2.DateCP, proc.ProcDate) <= 30
        ) THEN 1 ELSE 0 END as target_paid_30d

FROM procedurelog proc
LEFT JOIN patient pat ON proc.PatNum = pat.PatNum
LEFT JOIN procedurecode pc ON proc.CodeNum = pc.CodeNum
LEFT JOIN appointment appt ON proc.PatNum = appt.PatNum 
    AND proc.ProcDate = DATE(appt.AptDateTime)
LEFT JOIN fee f ON proc.CodeNum = f.CodeNum 
    AND f.FeeSched = pat.FeeSched
    AND (f.ClinicNum = proc.ClinicNum OR f.ClinicNum = 0)
LEFT JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
LEFT JOIN feeschedgroup fsg ON fs.FeeSchedNum = fsg.FeeSchedNum
-- Insurance Related Joins
LEFT JOIN claimproc cp ON proc.ProcNum = cp.ProcNum
LEFT JOIN claim c ON cp.ClaimNum = c.ClaimNum
LEFT JOIN claimpayment cpy ON cp.ClaimPaymentNum = cpy.ClaimPaymentNum

WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 5, 6)
    AND proc.ProcFee > 0  -- Add this condition to main WHERE clause

ORDER BY proc.ProcDate DESC;
