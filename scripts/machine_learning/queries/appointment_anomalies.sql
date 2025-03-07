-- Appointment Anomaly Checks
SELECT 
    'Appointments with future dates but marked as completed' as Validation,
    COUNT(*) as Count
FROM appointment 
WHERE 
    AptDateTime > '2025-02-01'
    AND AptStatus = 2

UNION ALL

SELECT 
    'Past appointments still marked as scheduled',
    COUNT(*)
FROM appointment 
WHERE 
    AptDateTime < '2025-01-01'
    AND AptStatus = 1

UNION ALL

SELECT 
    'Unscheduled appointments with specific times',
    COUNT(*)
FROM appointment 
WHERE 
    AptStatus = 6 
    AND AptDateTime IS NOT NULL

UNION ALL

SELECT 
    'Broken appointments with procedures marked as completed',
    COUNT(*)
FROM appointment a
JOIN procedurelog pl ON pl.AptNum = a.AptNum
WHERE 
    a.AptStatus = 5 
    AND pl.ProcStatus = 2; 