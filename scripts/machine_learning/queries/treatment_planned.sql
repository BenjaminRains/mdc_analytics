-- Treatment Planned Outreach
-- Identifies patients with unscheduled treatment plans
SELECT 
    patient.PatNum,
    patient.HmPhone,
    patient.WkPhone,
    patient.WirelessPhone,
    FORMAT(SUM(pl.ProcFee * (pl.BaseUnits + pl.UnitQty)), 2) AS '$FeeSum' 
FROM patient 
INNER JOIN procedurelog pl ON patient.PatNum = pl.PatNum
INNER JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum 
    AND pl.ProcStatus = 1  -- Treatment Planned
LEFT JOIN appointment ap ON patient.PatNum = ap.PatNum 
    AND ap.AptStatus = 1   -- scheduled apt
WHERE ap.AptNum IS NULL 
    AND patient.PatStatus = 0  -- Active Patient
    AND NOT pc.ProcCode LIKE 'D0%'  -- Exclude Diagnostic
    AND NOT pc.ProcCode LIKE 'D1%'  -- Exclude Preventative
GROUP BY patient.PatNum
HAVING SUM(pl.ProcFee * (pl.BaseUnits + pl.UnitQty)) > 0 
ORDER BY patient.LName, patient.FName, patient.PatNum;