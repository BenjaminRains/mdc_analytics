-- Testing and Validation Query for treatment_journey_ml.sql

-- Check for duplicate ProcNum entries
-- ProcNum is unique in procedurelog

-- Validate zero-fee procedures
SELECT 
    proc.ProcNum,
    proc.ProcDate,
    proc.ProcFee,
    pc.Descript as CategoryDescription
FROM procedurelog proc
LEFT JOIN procedurecode pc ON proc.CodeNum = pc.CodeNum
WHERE proc.ProcFee = 0;

-- Verify insurance plan information
SELECT 
    proc.ProcNum,
    a.InsPlan1,
    a.InsPlan2
FROM procedurelog proc
LEFT JOIN appointment a ON proc.PatNum = a.PatNum AND proc.ProcDate = DATE(a.AptDateTime)
WHERE proc.ProcFee = 0;

SELECT 
    proc.ProcNum,
    proc.ProcDate,
    proc.DateTP as PlanDate,
    proc.PatNum,
    CASE 
        WHEN pat.Birthdate = '0001-01-01' THEN NULL
        WHEN pat.Birthdate > proc.ProcDate THEN NULL
        ELSE TIMESTAMPDIFF(YEAR, pat.Birthdate, proc.ProcDate) 
    END as PatientAge,
    pat.Gender,
    CASE WHEN pat.HasIns != '' THEN 1 ELSE 0 END as HasInsurance,
    pat.BalTotal as TotalBalance,
    pat.InsEst as InsuranceEstimate,
    pc.ProcCat,
    pc.ProcCode,
    pc.Descript as ProcDescription,
    pc.TreatArea,
    proc.ProcFee as PlannedFee,
    CASE WHEN pc.IsMultiVisit = 1 THEN 1 ELSE 0 END as IsMultiVisit,
    DAYOFWEEK(proc.ProcDate) as DayOfWeek,
    MONTH(proc.ProcDate) as Month,
    CASE WHEN proc.ProcStatus = 2 THEN 1 ELSE 0 END as target_accepted,
    CASE WHEN EXISTS (
        SELECT 1 
        FROM paysplit ps 
        JOIN payment pay ON ps.PayNum = pay.PayNum
        WHERE ps.ProcNum = proc.ProcNum 
        AND DATEDIFF(pay.PayDate, proc.ProcDate) <= 30
    ) THEN 1 ELSE 0 END as target_paid_30d,
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
    CASE WHEN proc.ProcFee = 0 THEN 1 ELSE 0 END as IsZeroFeeProcedure,
    pc.Descript as CategoryDescription
FROM procedurelog proc
LEFT JOIN patient pat ON proc.PatNum = pat.PatNum
LEFT JOIN procedurecode pc ON proc.CodeNum = pc.CodeNum
WHERE proc.ProcDate >= '2023-01-01'
AND proc.ProcDate < '2024-01-01'
AND proc.ProcStatus IN (1, 2, 5, 6)
ORDER BY proc.ProcDate DESC;

-- Check distribution of communication types
SELECT 
    CommType,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM commlog), 2) as percentage
FROM commlog
GROUP BY CommType
ORDER BY count DESC;

-- Communication frequency calculation by type. commlog.CommType = numeric. 
    -- Check commlog.Note and commlog.CommType for more information. If CommType = 0 then the communication is via PbN. 
    -- find first instance of 'text' in commlog.Note when commlog.CommType = 0. 
    -- find first instance of 'email' in commlog.Note when commlog.CommType = 0. 
    -- find first instance of 'phone' in commlog.Note when commlog.CommType = 0. 
    -- CommType = '603' is a broken/cancelled/missed appointment. 
    -- CommType = '227, 228, 226, 425, 427,429, 430, 636, 509, 510, 571, 614, 615' is communication in office by staff. ignore for patient
    -- CommType = '432' is office staff and prescription refill note. ignore for patient
    -- CommType = '428' is in house communication. ignore for patient
    -- CommType = '431' is non patient communication. Mostly internal payment, changes, etc. ignore for patient
    -- Mode_ = '4' is from YAPI service by staff. ignore for patient


  -- Validation query for CommType = 0 in commlog
    -- Find all commlog.Note that don't start with 'patient text', 'email sent', or 'phone call' when CommType = 0
    -- deal with these cases. 
SELECT 
    commlog.Note
FROM 
    commlog
WHERE 
    commlog.CommType = 0
    AND NOT (
        LOWER(SUBSTRING(commlog.Note, 1, 12)) LIKE 'patient text%' OR
        LOWER(SUBSTRING(commlog.Note, 1, 10)) LIKE 'email sent%' OR
        LOWER(SUBSTRING(commlog.Note, 1, 10)) LIKE 'phone call%'
);

-- Index on PatNum in procedurelog
-- CREATE INDEX idx_procedurelog_patnum ON procedurelog (PatNum);

-- Index on ProcDate in procedurelog
-- CREATE INDEX idx_procedurelog_procdate ON procedurelog (ProcDate);

-- Index on ProcNum in procedurelog
-- CREATE INDEX idx_procedurelog_procnum ON procedurelog (ProcNum);

-- Index on PatNum in appointment
-- CREATE INDEX idx_appointment_patnum ON appointment (PatNum);

-- Index on AptDateTime in appointment
-- CREATE INDEX idx_appointment_aptdatetime ON appointment (AptDateTime);

-- New index for family-related queries
CREATE INDEX idx_proc_patient_date ON procedurelog (PatNum, ProcDate, ProcStatus);

-- Optimize family-related queries
CREATE INDEX idx_proc_guarantor_date ON procedurelog (PatNum, ProcDate, ProcStatus);

-- Optimize payment tracking
CREATE INDEX idx_proc_payment ON procedurelog (ProcNum, ProcFee, ProcStatus);

-- Optimize communication and appointment lookups
CREATE INDEX idx_proc_patient_date ON procedurelog (PatNum, ProcDate, ProcStatus);

-- Optimize procedure code lookups with fees
CREATE INDEX idx_proc_code_fee ON procedurelog (CodeNum, ProcFee, ProcStatus);

-- Optimize date-based lookups with multiple status filters
CREATE INDEX idx_proc_date_status ON procedurelog (ProcDate, ProcStatus, ProcFee);

-- Optimize historical procedure lookups
CREATE INDEX idx_proc_patient_history ON procedurelog (PatNum, ProcStatus, ProcDate, ProcFee);

