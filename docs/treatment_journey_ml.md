# Treatment Journey ML Query

```sql
SELECT 
    -- Identifiers and Dates
    proc.ProcNum,
    proc.ProcDate,
    proc.DateTP as PlanDate,
    
    -- Patient Features
    proc.PatNum,
    CASE 
        WHEN pat.Birthdate = '0001-01-01' THEN NULL  -- Handle invalid birthdates
        WHEN pat.Birthdate > proc.ProcDate THEN NULL  -- Handle future birthdates
        ELSE TIMESTAMPDIFF(YEAR, pat.Birthdate, proc.ProcDate) 
    END as PatientAge,
    pat.Gender,
    CASE WHEN pat.HasIns != '' THEN 1 ELSE 0 END as HasInsurance,
    
    -- Individual Financial Status
    pat.Bal_0_30 as Balance_0_30_Days,
    pat.Bal_31_60 as Balance_31_60_Days,
    pat.Bal_61_90 as Balance_61_90_Days,
    pat.BalOver90 as Balance_Over_90_Days,
    pat.BalTotal as TotalBalance,
    pat.InsEst as InsuranceEstimate,
    
    -- Family Features
    (SELECT COUNT(DISTINCT proclog2.ProcNum) 
     FROM procedurelog proclog2 
     JOIN patient p2 ON proclog2.PatNum = p2.PatNum 
     WHERE p2.Guarantor = pat.Guarantor 
     AND proclog2.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 1 YEAR)) as Family_Total_Procedures,
    
    -- Individual History
    (SELECT COUNT(DISTINCT proclog2.ProcNum) 
     FROM procedurelog proclog2 
     WHERE proclog2.PatNum = proc.PatNum 
     AND proclog2.ProcDate < proc.ProcDate 
     AND proclog2.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 1 YEAR)) as PastProcedures,
    
    (SELECT COUNT(DISTINCT proclog2.ProcNum) 
     FROM procedurelog proclog2 
     WHERE proclog2.PatNum = proc.PatNum 
     AND proclog2.ProcStatus = 2 
     AND proclog2.ProcDate < proc.ProcDate 
     AND proclog2.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 1 YEAR)) as PastCompletedProcedures,
    
    -- Procedure Features
    pc.ProcCat,
    pc.ProcCode,
    pc.Descript as ProcDescription,
    pc.TreatArea,
    proc.ProcFee as PlannedFee,
    CASE WHEN pc.IsMultiVisit = 1 THEN 1 ELSE 0 END as IsMultiVisit,
    
    -- Temporal Features
    DAYOFWEEK(proc.ProcDate) as DayOfWeek,
    MONTH(proc.ProcDate) as Month,
    
    -- Target Variables
    CASE WHEN proc.ProcStatus = 2 THEN 1 ELSE 0 END as target_accepted,
    CASE WHEN EXISTS (
        SELECT 1 
        FROM paysplit ps 
        JOIN payment pay ON ps.PayNum = pay.PayNum
        WHERE ps.ProcNum = proc.ProcNum 
        AND DATEDIFF(pay.PayDate, proc.ProcDate) <= 30
    ) THEN 1 ELSE 0 END as target_paid_30d,
    
    -- Payment Outcomes
    COALESCE(
        (SELECT SUM(ps.SplitAmt) 
         FROM paysplit ps 
         WHERE ps.ProcNum = proc.ProcNum), 0
    ) as TotalPaid,
    
    COALESCE(
        (SELECT SUM(claimproc.InsPayAmt) 
         FROM claimproc 
         WHERE claimproc.ProcNum = proc.ProcNum 
         AND claimproc.Status = 1), 0
    ) as InsurancePaid,
    
    COALESCE(
        (SELECT SUM(adj.AdjAmt) 
         FROM adjustment adj 
         WHERE adj.ProcNum = proc.ProcNum), 0
    ) as Adjustments,

    -- Flag for $0 Fee Procedures
    CASE WHEN proc.ProcFee = 0 THEN 1 ELSE 0 END as IsZeroFeeProcedure

FROM procedurelog proc
LEFT JOIN patient pat ON proc.PatNum = pat.PatNum
LEFT JOIN procedurecode pc ON proc.CodeNum = pc.CodeNum
WHERE proc.ProcDate >= '2023-01-01'
AND proc.ProcDate < '2024-01-01'
AND proc.ProcStatus IN (1, 2, 5, 6)
ORDER BY proc.ProcDate DESC;
```