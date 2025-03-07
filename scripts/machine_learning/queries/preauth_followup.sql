-- Outstanding Preauth Follow-up
-- Track preauthorizations older than 30 days
SELECT 
    cl.PatNum, 
    p.PatNum AS 'RawPatNum',
    cl.DateSent, 
    ca.CarrierName, 
    ca.Phone, 
    pl.ProcFee, 
    pc.ProcCode 
FROM claim cl
INNER JOIN patient p ON p.PatNum = cl.PatNum
INNER JOIN insplan i ON i.PlanNum = cl.PlanNum
INNER JOIN carrier ca ON ca.CarrierNum = i.CarrierNum
INNER JOIN claimproc cp ON cp.ClaimNum = cl.ClaimNum
INNER JOIN procedurelog pl ON pl.ProcNum = cp.ProcNum
INNER JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE cl.ClaimType = 'PreAuth' 
    AND cl.ClaimStatus = 'S'
    AND DateSent < (CURDATE() - INTERVAL 30 DAY) 
ORDER BY DateSent, p.LName, p.FName;