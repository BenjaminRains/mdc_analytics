-- Capitation Utilization Report with plan info
-- Tracks dental procedures performed under capitation insurance plans for specified date range and carrier

SET @StartDate = '2014-07-01', 
    @EndDate = '2014-08-31', 
    @CarrierName = '%%';  -- Use '%%' for all carriers or specify carrier name

SELECT 
    car.CarrierName,
    CONCAT(patSub.LName, ', ', patSub.FName) AS 'Subscriber',
    patSub.SSN AS 'Subsc SSN',
    CONCAT(patPat.LName, ', ', patPat.FName) AS 'Patient',
    patPat.Birthdate AS 'Pat DOB',
    pc.ProcCode AS 'Code',
    pc.Descript AS 'Proc Description',
    pl.ToothNum AS 'Tth',
    pl.Surf AS 'Surf',
    pl.ProcDate AS 'Date',
    pl.ProcFee - cp.WriteOff AS 'Co-Pay',
    emp.EmpName AS 'Employer',
    patPat.Zip AS 'Pat Zip',
    ib.SubscriberID,
    CASE pp.Relationship 
        WHEN 0 THEN 'Self'
        WHEN 1 THEN 'Spouse'
        WHEN 2 THEN 'Child'
        WHEN 3 THEN 'Employee'
        WHEN 4 THEN 'HandicapDep'
        WHEN 5 THEN 'SignifOther'
        WHEN 6 THEN 'InjuredPlantiff'
        WHEN 7 THEN 'LifePartner'
        WHEN 8 THEN 'Dependant'
        ELSE ''
    END AS 'RelationToSubscriber'
FROM procedurelog pl
INNER JOIN patient patPat ON pl.PatNum = patPat.PatNum
INNER JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
INNER JOIN claimproc cp ON pl.ProcNum = cp.ProcNum 
    AND cp.Status = 7 
    AND cp.NoBillIns = 0 
INNER JOIN insplan ip ON cp.PlanNum = ip.PlanNum 
    AND ip.PlanType = 'c'
INNER JOIN inssub ib ON cp.InsSubNum = ib.InsSubNum
INNER JOIN patient patSub ON patSub.PatNum = ib.Subscriber
INNER JOIN carrier car ON car.CarrierNum = ip.CarrierNum 
    AND car.CarrierName LIKE @CarrierName
INNER JOIN employer emp ON emp.EmployerNum = ip.EmployerNum
LEFT JOIN patplan pp ON pp.PatNum = pl.PatNum 
    AND pp.InsSubNum = ib.InsSubNum
WHERE pl.ProcStatus = 2
AND pl.ProcDate BETWEEN @StartDate AND @EndDate; 