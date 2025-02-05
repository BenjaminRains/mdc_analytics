-- Fee Schedule and Expected Payments
-- the feeschedgroup table suggests fee schedules are grouped by clinic/provider, meaning different 
-- fee levels may apply. 
-- insbluebook table logs historical insurance payments, useful for tracking how different carriers pay for the same procedures.
-- insbluebooklog provides adjustment logs, helping identify discrepancies in billed vs allowed fees. 

-- 1. First check carriers and their insurance plans
SELECT 
    c.CarrierNum,
    c.CarrierName,
    COUNT(DISTINCT i.PlanNum) as NumPlans
FROM carrier c
LEFT JOIN insplan i ON c.CarrierNum = i.CarrierNum
GROUP BY c.CarrierNum, c.CarrierName
HAVING NumPlans > 0
ORDER BY NumPlans DESC;

-- 2. Then check insurance plans with fee schedules
SELECT 
    i.PlanNum,
    c.CarrierName,
    i.FeeSched,
    COUNT(DISTINCT fsg.FeeSchedNum) as NumFeeScheduleGroups
FROM insplan i
JOIN carrier c ON i.CarrierNum = c.CarrierNum
LEFT JOIN feeschedgroup fsg ON i.FeeSched = fsg.FeeSchedNum
WHERE i.FeeSched IS NOT NULL
GROUP BY i.PlanNum, c.CarrierName, i.FeeSched;

-- Check if feeschedgroup table has any data
SELECT COUNT(*) as TotalGroups, 
       COUNT(DISTINCT FeeSchedNum) as UniqueFeeScheds 
FROM feeschedgroup;

-- Check if feesched table has any data
SELECT COUNT(*) as TotalFeeScheds, 
       COUNT(DISTINCT FeeSchedNum) as UniqueFeeScheds 
FROM feesched;

-- Check if fee table has any data
SELECT COUNT(*) as TotalFees, 
       COUNT(DISTINCT FeeSched) as UniqueFeeScheds,
       COUNT(DISTINCT CodeNum) as UniqueCodes
FROM fee;

-- Check table structures to verify columns
DESCRIBE feeschedgroup;
DESCRIBE feesched;
DESCRIBE fee;

-- 4. Check claim procedures with payments
SELECT 
    c.CarrierName,
    COUNT(DISTINCT cp.ClaimProcNum) as NumClaimProcs,
    COUNT(DISTINCT cl.ClaimNum) as NumClaims
FROM carrier c
JOIN insplan i ON c.CarrierNum = i.CarrierNum
JOIN claimproc cp ON i.PlanNum = cp.PlanNum
JOIN claim cl ON cp.ClaimNum = cl.ClaimNum
WHERE cl.ClaimStatus != ''
GROUP BY c.CarrierName;

-- 3. Fee Schedule and Payment Analysis
SELECT 
    c.CarrierName,
    fsg.Description as FeeScheduleGroup,
    COUNT(DISTINCT f.CodeNum) as NumProcedureCodes,
    AVG(f.Amount) as AvgFeeScheduleAmount,
    AVG(cp.InsPayAmt) as AvgActualPayment,
    AVG(cp.WriteOff) as AvgWriteOff,
    COUNT(DISTINCT cp.ClaimProcNum) as NumClaimProcs
FROM carrier c
JOIN insplan i ON c.CarrierNum = i.CarrierNum
JOIN feeschedgroup fsg ON i.FeeSched = fsg.FeeSchedNum
JOIN feesched fs ON fsg.FeeSchedNum = fs.FeeSchedNum
JOIN fee f ON fs.FeeSchedNum = f.FeeSched
LEFT JOIN claimproc cp ON i.PlanNum = cp.PlanNum
GROUP BY c.CarrierName, fsg.Description
HAVING NumClaimProcs > 0
ORDER BY c.CarrierName;

-- 4. Payment Discrepancy Analysis
SELECT 
    c.CarrierName,
    COUNT(DISTINCT cp.ClaimProcNum) as TotalProcedures,
    SUM(CASE WHEN cp.FeeBilled <> (cp.InsPayAmt + cp.WriteOff) THEN 1 ELSE 0 END) as PaymentDiscrepancies,
    AVG(cp.FeeBilled) as AvgBilledAmount,
    AVG(cp.InsPayAmt) as AvgPaidAmount,
    AVG(cp.WriteOff) as AvgWriteOff,
    COUNT(DISTINCT a.AdjNum) as NumAdjustments
FROM carrier c
JOIN claim cl ON cl.PlanNum = c.CarrierNum
JOIN claimproc cp ON cl.ClaimNum = cp.ClaimNum
LEFT JOIN adjustment a ON cl.PatNum = a.PatNum AND cl.DateService = a.ProcDate
WHERE cl.ClaimStatus != ''
GROUP BY c.CarrierName
HAVING PaymentDiscrepancies > 0
ORDER BY PaymentDiscrepancies DESC;