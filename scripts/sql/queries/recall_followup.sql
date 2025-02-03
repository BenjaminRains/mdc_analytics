-- Recall Follow-up Query
-- Patients who need followup after specific procedures
SET @FromDate = '2008-12-01', @ToDate = '2008-12-30';

SELECT 
    patient.PatNum, 
    DATE_FORMAT(MAX(ProcDate), '%m/%d/%Y') AS 'LastVisit', 
    COUNT(DISTINCT procedurelog.ProcDate) AS '#Apts' 
FROM patient
INNER JOIN procedurelog ON patient.PatNum = procedurelog.PatNum
WHERE patient.PatNum IN (
    SELECT DISTINCT p.PatNum 
    FROM patient p
    INNER JOIN procedurelog pl ON p.PatNum = pl.PatNum
    INNER JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum 
        AND pc.ProcCode IN ('D0120', 'D1110', 'D1204')
    WHERE pl.ProcStatus = '2'  -- Completed
)
AND procedurelog.ProcStatus = 2 
AND patient.PatStatus = 0      -- Active patients
GROUP BY procedurelog.PatNum
HAVING (MIN(ProcDate) BETWEEN @FromDate AND @ToDate) 
    AND COUNT(DISTINCT procedurelog.ProcDate) = 1
ORDER BY patient.LName, patient.FName;