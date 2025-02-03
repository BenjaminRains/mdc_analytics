-- Create a patient level analysis table. machine learning targets could be added here. 


 -- Patient Communication features from commlog table

    -- Communication Features
    
    -- Days since last communication (through guarantor)
    (SELECT DATEDIFF(CURDATE(), DATE(MAX(commlog.CommDateTime))) 
     FROM commlog 
     JOIN patient p ON commlog.PatNum = p.PatNum
     WHERE p.Guarantor = pat.Guarantor
     AND commlog.CommType = 0
     AND (
         LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'patient text%' OR
         LOWER(SUBSTRING(commlog.Note, 1, 10)) LIKE 'email sent%' OR
         LOWER(SUBSTRING(commlog.Note, 1, 10)) LIKE 'phone call%' OR
         LOWER(SUBSTRING(commlog.Note, 1, 5)) LIKE 'call%' OR
         LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'left message%'
     )) as DaysSinceLastComm,
    
    -- Total communication counts by type (lifetime)
    (SELECT COUNT(*) 
     FROM commlog 
     WHERE commlog.PatNum = pat.PatNum 
     AND commlog.CommType = 0 
     AND LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'patient text%') as TotalTextComm,
    
    (SELECT COUNT(*) 
     FROM commlog 
     WHERE commlog.PatNum = pat.PatNum 
     AND commlog.CommType = 0 
     AND LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'email sent%') as TotalEmailComm,
    
    (SELECT COUNT(*) 
     FROM commlog 
     WHERE commlog.PatNum = pat.PatNum 
     AND commlog.CommType = 0 
     AND (
         LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'phone call%' OR
         LOWER(SUBSTRING(commlog.Note, 1, 6)) LIKE 'called%' OR
         LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'left message%'
     )) as TotalPhoneComm,
    
    -- Communication preference (most used method)
    CASE 
        WHEN (
            SELECT COUNT(*) 
            FROM commlog 
            WHERE commlog.PatNum = pat.PatNum 
            AND commlog.CommType = 0 
            AND LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'patient text%'
        ) > GREATEST(
            (SELECT COUNT(*) 
             FROM commlog 
             WHERE commlog.PatNum = pat.PatNum 
             AND commlog.CommType = 0 
             AND LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'email sent%'),
            (SELECT COUNT(*) 
             FROM commlog 
             WHERE commlog.PatNum = pat.PatNum 
             AND commlog.CommType = 0 
             AND (
                 LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'phone call%' OR
                 LOWER(SUBSTRING(commlog.Note, 1, 6)) LIKE 'called%' OR
                 LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'left message%'
             ))
        ) THEN 'TEXT'
        WHEN (
            SELECT COUNT(*) 
            FROM commlog 
            WHERE commlog.PatNum = pat.PatNum 
            AND commlog.CommType = 0 
            AND LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'email sent%'
        ) > (
            SELECT COUNT(*) 
            FROM commlog 
            WHERE commlog.PatNum = pat.PatNum 
            AND commlog.CommType = 0 
            AND (
                LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'phone call%' OR
                LOWER(SUBSTRING(commlog.Note, 1, 6)) LIKE 'called%' OR
                LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'left message%'
            )
        ) THEN 'EMAIL'
        ELSE 'PHONE'
    END as PreferredCommMethod,
    
    -- Communication frequency (communications per year)
    (SELECT COUNT(*) 
     FROM commlog 
     WHERE commlog.PatNum = pat.PatNum 
     AND commlog.CommType = 0) /
    GREATEST(TIMESTAMPDIFF(YEAR, 
        (SELECT MIN(CommDateTime) FROM commlog WHERE PatNum = pat.PatNum), 
        CURDATE()), 1) as CommsPerYear,

    -- Patient Appointment Features
    -- Time since last appointment
    (SELECT DATEDIFF(CURDATE(), DATE(MAX(appt.AptDateTime))) 
     FROM appointment appt 
     WHERE appt.PatNum = pat.PatNum) as DaysSinceLastAppointment,
    
    -- Total count of appointments within the last 2 years
    (SELECT COUNT(*) 
     FROM appointment appt 
     WHERE appt.PatNum = pat.PatNum 
     AND appt.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)) as TotalAppointmentsLast2Years,
    
    -- Total count of appointments within the last 12 months
    (SELECT COUNT(*) 
     FROM appointment appt 
     WHERE appt.PatNum = pat.PatNum 
     AND appt.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)) as TotalAppointmentsLast12Months,
    
    -- Total count of appointments within the last 3 months
    (SELECT COUNT(*) 
     FROM appointment appt 
     WHERE appt.PatNum = pat.PatNum 
     AND appt.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)) as TotalAppointmentsLast3Months,
    
    -- Count of missed and cancelled appointments (AptStatus = 5 'broken')
    (SELECT COUNT(*) 
     FROM appointment appt 
     WHERE appt.PatNum = pat.PatNum 
     AND appt.AptStatus = 5) as MissedCancelledAppointments,

    -- Individual Financial Status
    pat.Bal_0_30 as Balance_0_30_Days,
    pat.Bal_31_60 as Balance_31_60_Days,
    pat.Bal_61_90 as Balance_61_90_Days,
    pat.BalOver90 as Balance_Over_90_Days,
    pat.BalTotal as TotalBalance,
    pat.InsEst as InsuranceEstimate,

    -- Appointment History Features
    -- Total appointment duration (in minutes) in last 12 months
    (SELECT COALESCE(SUM(CHAR_LENGTH(a.Pattern)*5), 0)
     FROM appointment a 
     WHERE a.PatNum = pat.PatNum
     AND a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)) as TotalAppointmentMinutesLast12Months,
    
    -- Average appointment duration
    (SELECT COALESCE(AVG(CHAR_LENGTH(a.Pattern)*5), 0)
     FROM appointment a 
     WHERE a.PatNum = pat.PatNum
     AND a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)) as AvgAppointmentDuration,
    
    -- Count appointments by status in last 12 months
    (SELECT COUNT(*) 
     FROM appointment a 
     WHERE a.PatNum = pat.PatNum 
     AND a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
     AND a.AptStatus = 1) as ScheduledAppointments,
    
    (SELECT COUNT(*) 
     FROM appointment a 
     WHERE a.PatNum = pat.PatNum 
     AND a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
     AND a.AptStatus = 2) as CompletedAppointments,
    
    (SELECT COUNT(*) 
     FROM appointment a 
     WHERE a.PatNum = pat.PatNum 
     AND a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
     AND a.AptStatus LIKE '5' OR '6') as BrokenAppointments,
    
    -- Provider consistency (count of distinct providers in last 12 months)
    (SELECT COUNT(DISTINCT a.ProvNum)
     FROM appointment a 
     WHERE a.PatNum = pat.PatNum
     AND a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)) as DistinctProvidersCount,
    
    -- Hygienist consistency (count of distinct hygienists in last 12 months)
    (SELECT COUNT(DISTINCT a.ProvHyg)
     FROM appointment a 
     WHERE a.PatNum = pat.PatNum
     AND a.ProvHyg > 0
     AND a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)) as DistinctHygienistsCount,
    
    -- Most common appointment time of day (morning=1, afternoon=2, evening=3)
    (SELECT 
        CASE 
            WHEN TIME(a.AptDateTime) < '12:00:00' THEN 1
            WHEN TIME(a.AptDateTime) < '17:00:00' THEN 2
            ELSE 3
        END as TimeOfDay
     FROM appointment a 
     WHERE a.PatNum = pat.PatNum
     AND a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
     GROUP BY TimeOfDay
     ORDER BY COUNT(*) DESC
     LIMIT 1) as PreferredTimeOfDay,

    -- Average notice period for cancellations (in days)
    (SELECT COALESCE(AVG(DATEDIFF(a.AptDateTime, a.DateTStamp)), 0)
     FROM appointment a 
     WHERE a.PatNum = pat.PatNum
     AND a.AptStatus = 5  -- Broken/Cancelled
     AND a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)) as AvgCancellationNoticeDays,

    -- Lifetime Patient Value Features
    -- Total lifetime payments from patient
    COALESCE(
        (SELECT SUM(ps.SplitAmt) 
         FROM paysplit ps 
         WHERE ps.PatNum = pat.PatNum), 0
    ) as LifetimePayments,
    
    -- Total value of planned treatments (not yet completed)
    COALESCE(
        (SELECT SUM(pl.ProcFee) 
         FROM procedurelog pl 
         WHERE pl.PatNum = pat.PatNum
         AND pl.ProcStatus = 1), 0
    ) as PlannedTreatmentValue,
    
    -- Ratio of lifetime payments to planned treatment value
    CASE 
        WHEN (SELECT SUM(pl.ProcFee) 
              FROM procedurelog pl 
              WHERE pl.PatNum = pat.PatNum
              AND pl.ProcStatus = 1) > 0 
        THEN 
            (SELECT SUM(ps.SplitAmt) 
             FROM paysplit ps 
             WHERE ps.PatNum = pat.PatNum) * 100.0 / 
            (SELECT SUM(pl.ProcFee) 
             FROM procedurelog pl 
             WHERE pl.PatNum = pat.PatNum
             AND pl.ProcStatus = 1)
        ELSE NULL
    END as PaymentToPlanRatio

    -- Patient Financial History Features
    -- Insurance payments received
    COALESCE(
        (SELECT SUM(c.InsPayAmt)
         FROM claim c
         WHERE c.PatNum = pat.PatNum), 0
    ) as TotalInsurancePayments,
    
    -- Insurance write-offs
    COALESCE(
        (SELECT SUM(c.Writeoff)
         FROM claim c
         WHERE c.PatNum = pat.PatNum), 0
    ) as TotalWriteoffs,
    
    -- Patient direct payments
    COALESCE(
        (SELECT SUM(ps.SplitAmt)
         FROM paysplit ps
         WHERE ps.PatNum = pat.PatNum), 0
    ) as TotalPatientPayments,
    
    -- Patient adjustments
    COALESCE(
        (SELECT SUM(adj.AdjAmt)
         FROM adjustment adj
         WHERE adj.PatNum = pat.PatNum), 0
    ) as TotalPatientAdjustments,
    
    -- Total production value (completed procedures)
    COALESCE(
        (SELECT SUM(pl2.procfee * (pl2.BaseUnits + pl2.UnitQty))
         FROM procedurelog pl2
         WHERE pl2.PatNum = pat.PatNum
         AND pl2.ProcStatus = 2), 0
    ) as TotalProductionValue,
    
    -- Payment ratio (Total payments / Total production)
    CASE 
        WHEN (SELECT SUM(pl2.procfee * (pl2.BaseUnits + pl2.UnitQty))
              FROM procedurelog pl2
              WHERE pl2.PatNum = pat.PatNum
              AND pl2.ProcStatus = 2) > 0 
        THEN 
            ((SELECT COALESCE(SUM(c.InsPayAmt), 0)
              FROM claim c
              WHERE c.PatNum = pat.PatNum) +
             (SELECT COALESCE(SUM(ps.SplitAmt), 0)
              FROM paysplit ps
              WHERE ps.PatNum = pat.PatNum)) * 100.0 /
            (SELECT SUM(pl2.procfee * (pl2.BaseUnits + pl2.UnitQty))
             FROM procedurelog pl2
             WHERE pl2.PatNum = pat.PatNum
             AND pl2.ProcStatus = 2)
        ELSE NULL
    END as PaymentToProductionRatio