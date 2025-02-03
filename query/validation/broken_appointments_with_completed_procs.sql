SELECT 
    COUNT(*) as TotalAppointments,
    COUNT(CASE WHEN AptStatus = 5 THEN 1 END) as BrokenAppointments,
    MIN(AptDateTime) as EarliestDate,
    MAX(AptDateTime) as LatestDate
FROM appointment
WHERE 
    AptDateTime >= '2016-02-29'
    AND AptDateTime < '2016-03-02';

SELECT 
    AptStatus,
    COUNT(*) as AppointmentCount
FROM appointment
WHERE 
    AptDateTime >= '2016-02-29'
    AND AptDateTime < '2016-03-02'
GROUP BY 
    AptStatus
ORDER BY 
    AptStatus;

SELECT 
    a.AptNum,
    a.AptDateTime,
    a.Note as AppointmentNote,
    pl.ProcStatus,
    pc.Descript as ProcedureDescription
FROM appointment a
LEFT JOIN procedurelog pl ON pl.AptNum = a.AptNum
LEFT JOIN procedurecode pc ON pc.CodeNum = pl.CodeNum
WHERE 
    a.AptStatus = 5
    AND pl.ProcStatus = 2
LIMIT 10; 