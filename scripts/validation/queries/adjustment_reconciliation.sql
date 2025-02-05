-- insbluebooklog table may indicate systematic underpayments that require adjustments.
-- procedurelog table provides a history of all procedures, allowing longitudinal tracking of payments.

-- Find insurance plans that consistently require adjustments.
-- Join through claim table to connect procedures with carriers
SELECT 
    carr.CarrierName,
    COUNT(DISTINCT a.AdjNum) AS NumAdjustments,
    SUM(a.AdjAmt) AS TotalAdjustments,
    COUNT(DISTINCT cl.ClaimNum) AS NumClaims,
    AVG(cl.InsPayAmt) AS AvgInsurancePayment,
    SUM(cl.WriteOff) AS TotalWriteOffs
FROM adjustment a
JOIN claim cl ON a.PatNum = cl.PatNum 
    AND a.ProcDate = cl.DateService  -- Link adjustments to claims via patient and service date
JOIN carrier carr ON cl.PlanNum = carr.CarrierNum
WHERE cl.ClaimStatus != '' -- Ensure we only look at processed claims
GROUP BY carr.CarrierName
HAVING NumAdjustments > 0
ORDER BY TotalAdjustments DESC;
-- Expected outcome: Identify carriers frequently requiring manual adjustments. 


-- Verify that insurance write-offs don't exceed claim limits. 
SELECT cp.ClaimProcNum, cp.ClaimNum, cp.InsPayAmt, cp.WriteOff, (cp.InsPayAmt + cp.WriteOff) AS TotalInsurance
FROM claimproc cp
JOIN claim c ON cp.ClaimNum = c.ClaimNum
WHERE cp.FeeBilled <> (cp.InsPayAmt + cp.WriteOff);
-- Expected outcome: Identify claims with discrepancies between InsPayAmt and WriteOff.


-- Analyze long-term claim payment trends per carrier.
SELECT 
    c.CarrierNum,
    c.CarrierName,
    YEAR(cl.DateService) AS Year,
    AVG(cl.InsPayAmt) AS AvgPaid,
    COUNT(cl.ClaimNum) AS NumClaims
FROM carrier c
JOIN claim cl ON cl.PlanNum = c.CarrierNum
WHERE cl.ClaimStatus != ''
    AND cl.DateService IS NOT NULL
GROUP BY c.CarrierNum, c.CarrierName, YEAR(cl.DateService)
ORDER BY c.CarrierNum, Year;
-- Expected outcome: Spot trends in insurance payments over multiple years. 


-- Consolidated carrier adjustment analysis with payment trends
SELECT 
    carr.CarrierName,
    COUNT(DISTINCT a.AdjNum) AS NumAdjustments,
    SUM(a.AdjAmt) AS TotalAdjustments,
    AVG(cl.InsPayAmt) AS AvgPaymentAmount,
    SUM(CASE WHEN cl.ClaimFee <> (cl.InsPayAmt + cl.WriteOff) THEN 1 ELSE 0 END) AS PaymentDiscrepancies
FROM adjustment a
JOIN claim cl ON a.PatNum = cl.PatNum 
    AND a.ProcDate = cl.DateService
JOIN carrier carr ON cl.PlanNum = carr.CarrierNum
WHERE cl.ClaimStatus != ''
GROUP BY carr.CarrierName
HAVING PaymentDiscrepancies > 0
ORDER BY TotalAdjustments DESC
LIMIT 200;
-- Expected outcome: Identify carriers with significant payment discrepancies.


-- Track adjustment patterns over time
SELECT 
    carr.CarrierName,
    DATE_FORMAT(a.AdjDate, '%Y-%m') AS AdjustmentMonth,
    COUNT(DISTINCT a.AdjNum) AS AdjustmentCount,
    SUM(a.AdjAmt) AS MonthlyAdjustmentTotal,
    AVG(ibb.InsPayAmt) AS AvgInsurancePayment,
    COUNT(DISTINCT ibbl.InsBlueBookLogNum) AS NumFeeOverrides
FROM adjustment a
JOIN claim cl ON a.PatNum = cl.PatNum 
    AND a.ProcDate = cl.DateService
JOIN carrier carr ON cl.PlanNum = carr.CarrierNum
LEFT JOIN insbluebook ibb ON carr.CarrierNum = ibb.CarrierNum
    AND cl.PlanNum = ibb.PlanNum
    AND DATE_FORMAT(a.AdjDate, '%Y-%m') = DATE_FORMAT(ibb.ProcDate, '%Y-%m')
LEFT JOIN insbluebooklog ibbl ON ibb.ClaimNum = cl.ClaimNum
WHERE cl.ClaimStatus != ''
GROUP BY carr.CarrierName, DATE_FORMAT(a.AdjDate, '%Y-%m')
ORDER BY carr.CarrierName, AdjustmentMonth
LIMIT 200;
-- Expected outcome: Identify patterns in adjustments over time.
