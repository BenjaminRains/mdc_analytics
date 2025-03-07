-- Capitation Utilization Report
-- Tracks utilization of capitation insurance plans and related procedures

-- Set report parameters
SET @StartDate = '2013-02-01';
SET @EndDate = '2014-02-28';
SET @CarrierName = '%%';  -- Use '%%' for all carriers or specific carrier name

-- Main report query
SELECT 
    -- Carrier and Patient Information
    car.CarrierName,
    CONCAT(patSub.LName, ', ', patSub.FName) AS 'Subscriber',
    patSub.SSN AS 'Subscriber SSN',
    CONCAT(patPat.LName, ', ', patPat.FName) AS 'Patient',
    patPat.Birthdate AS 'Patient DOB',
    
    -- Procedure Information
    pc.ProcCode AS 'Code',
    pc.Descript AS 'Procedure Description',
    pl.ToothNum AS 'Tooth',
    pl.Surf AS 'Surface',
    pl.ProcDate AS 'Date',
    
    -- Financial Information
    pl.ProcFee AS 'UCR Fee',
    (pl.ProcFee - cp.WriteOff) AS 'Co-Pay'

FROM procedurelog pl
    -- Join patient information
    INNER JOIN patient patPat 
        ON pl.PatNum = patPat.PatNum
    
    -- Join procedure codes
    INNER JOIN procedurecode pc 
        ON pl.CodeNum = pc.CodeNum
    
    -- Join claim processing
    INNER JOIN claimproc cp 
        ON pl.ProcNum = cp.ProcNum 
        AND cp.Status = 7          -- Complete status
        AND cp.NoBillIns = 0       -- Billable to insurance
    
    -- Join insurance plan information
    INNER JOIN insplan ip 
        ON cp.PlanNum = ip.PlanNum 
        AND ip.PlanType = 'c'      -- Capitation plans only
    
    -- Join subscriber information
    INNER JOIN inssub ib 
        ON cp.InsSubNum = ib.InsSubNum
    INNER JOIN patient patSub 
        ON patSub.PatNum = ib.Subscriber
    
    -- Join carrier information
    INNER JOIN carrier car 
        ON car.CarrierNum = ip.CarrierNum 
        AND car.CarrierName LIKE @CarrierName

WHERE 
    pl.ProcStatus = 2              -- Completed procedures only
    AND pl.ProcDate BETWEEN @StartDate AND @EndDate

ORDER BY 
    car.CarrierName,
    patSub.LName,
    patPat.LName,
    pl.ProcDate;