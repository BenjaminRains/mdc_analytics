-- Insurance Claim Processing and Payments

-- insplan and inssub tables clarify the relationship between patients, plans, and carriers. 
-- insverify and insverifyhist tables show whether a claim was filed with verified insurance information. 
-- the procedurelog table is the core source for treatment records, linking to claims and payments.


-- Validate if claims are linked to active insurance plans
SELECT c.ClaimNum, p.PatNum, i.PlanNum, i.CarrierNum, s.DateEffective, s.DateTerm
FROM claim c
JOIN patient p ON c.PatNum = p.PatNum
JOIN inssub s ON p.PlanNum = s.PlanNum
JOIN insplan i ON s.PlanNum = i.PlanNum
WHERE c.DateService BETWEEN s.DateEffective AND s.DateTerm;
-- Expected outcome: Ensure claims were submitted for activve plans at the time of service.


-- Identify claims with unverified insurance information.
SELECT c.ClaimNum, p.PatNum, iv.DateLastVerified
FROM claim c
JOIN patient p ON c.PatNum = p.PatNum
LEFT JOIN insverify iv ON iv.FKey = p.PatNum
WHERE iv.DateLastVerified IS NULL OR iv.DateLastVerified < DATE_SUB(CURDATE(), INTERVAL 1 YEAR);
-- Expected outcome: Find claims submitted without recent insurance verification. 

-- Match procedures to claims and payments. 
SELECT pl.ProcNum, c.ClaimNum, cp.InsPayAmt, pl.ProcFee, cp.DedApplied, cp.WriteOff
FROM procedurelog pl
JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
JOIN claim c ON cp.ClaimNum = c.ClaimNum
WHERE (cp.InsPayAmt + cp.DedApplied + cp.WriteOff) <> pl.ProcFee;
-- Expected outcome: Identify procedures where billed and paid amounts don't reconcile. 

-- 1. Insurance Plan and Carrier Validation
SELECT 
    c.CarrierNum,
    c.CarrierName,
    COUNT(DISTINCT i.PlanNum) as NumActivePlans,
    COUNT(DISTINCT cl.ClaimNum) as NumClaims,
    COUNT(DISTINCT p.PatNum) as NumPatients,
    MIN(s.DateEffective) as EarliestPlanDate,
    MAX(s.DateTerm) as LatestTermDate
FROM carrier c
LEFT JOIN insplan i ON c.CarrierNum = i.CarrierNum
LEFT JOIN inssub s ON i.PlanNum = s.PlanNum
LEFT JOIN claim cl ON s.PlanNum = cl.PlanNum
LEFT JOIN patient p ON cl.PatNum = p.PatNum
GROUP BY c.CarrierNum, c.CarrierName
ORDER BY NumClaims DESC;

-- 2. Claims Processing Analysis
SELECT 
    c.CarrierName,
    COUNT(cl.ClaimNum) as TotalClaims,
    SUM(CASE WHEN iv.DateLastVerified IS NULL THEN 1 ELSE 0 END) as UnverifiedClaims,
    AVG(cl.InsPayAmt) as AvgPayment,
    SUM(cl.WriteOff) as TotalWriteOffs,
    COUNT(DISTINCT pl.ProcNum) as NumProcedures
FROM carrier c
JOIN claim cl ON cl.PlanNum = c.CarrierNum
LEFT JOIN insverify iv ON iv.FKey = cl.PatNum
LEFT JOIN claimproc cp ON cl.ClaimNum = cp.ClaimNum
LEFT JOIN procedurelog pl ON cp.ProcNum = pl.ProcNum
WHERE cl.ClaimStatus != ''
GROUP BY c.CarrierName
HAVING TotalClaims > 0
ORDER BY TotalClaims DESC;