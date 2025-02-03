-- Part 1: Comprehensive Appointment Status Analysis
SELECT 
    AptStatus,
    CASE AptStatus
        WHEN 1 THEN 'Scheduled'
        WHEN 2 THEN 'Completed'
        WHEN 3 THEN 'Unspecified'
        WHEN 4 THEN 'ASAP'
        WHEN 5 THEN 'Broken/Missed'
        WHEN 6 THEN 'Unscheduled'
        WHEN 7 THEN 'WebSched'
        ELSE 'Unknown'
    END as StatusDescription,
    COUNT(*) as AppointmentCount,
    COUNT(DISTINCT PatNum) as UniquePatients,
    MIN(AptDateTime) as EarliestAppointment,
    MAX(AptDateTime) as LatestAppointment,
    -- Calculate percentages of total
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as PercentageOfTotal,
    -- Check procedure linkage
    COUNT(DISTINCT pl.ProcNum) as LinkedProcedures,
    -- Check completed procedures on non-completed appointments
    COUNT(CASE WHEN pl.ProcStatus = 2 THEN 1 END) as CompletedProcedures
FROM appointment a
LEFT JOIN procedurelog pl ON pl.AptNum = a.AptNum
GROUP BY 
    AptStatus
ORDER BY 
    AptStatus;

-- Part 2: Data Quality Validation Checks
SELECT 
    ValidationCheck,
    ValidationCount
FROM (
    SELECT 
        'Appointments with future dates but marked as completed' as ValidationCheck,
        COUNT(*) as ValidationCount
    FROM appointment 
    WHERE 
        AptDateTime > CURDATE() 
        AND AptStatus = 2
    UNION ALL
    SELECT 
        'Past appointments still marked as scheduled',
        COUNT(*)
    FROM appointment 
    WHERE 
        AptDateTime < CURDATE() 
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
        AND pl.ProcStatus = 2
) validations; 