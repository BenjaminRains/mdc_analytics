-- Raw Procedure Data Query
-- Extracts detailed procedure records with all relevant columns
-- Now includes treatment plan context and periodontal information
-- Date filter: 2024-01-01 to 2025-01-01
-- CTEs used:
SELECT 
    -- Procedure core information
    pl.ProcNum,
    pl.PatNum,
    pl.ProvNum,
    pl.ProcDate,
    pl.ProcStatus,
    pl.ProcFee,
    pl.CodeNum,
    pl.AptNum,
    pl.DateComplete,
    pl.ToothNum,
    pl.Surf,
    pl.MedicalCode,
    pl.DiagnosticCode,
    pl.ClaimNote,
    pl.ClinicNum,
    pl.UnitQty,
    pl.Urgency,
    pl.Discount,
    
    -- Procedure code information
    pc.ProcCode,
    pc.Descript AS ProcDescription,
    pc.TreatArea,
    pc.IsHygiene,
    pc.IsRadiology,
    pc.IsMultiVisit,
    pc.ProcCat AS ProcedureCategory,
    pc.LaymanTerm,
    
    -- Patient information
    pat.LName AS PatientLastName,
    pat.FName AS PatientFirstName,
    
    -- Provider information
    prov.Abbr AS ProviderAbbr,
    
    -- Treatment plan information
    tp.TreatPlanNum,
    tp.DateTP AS TreatPlanDate,
    tp.TPStatus,
    tp.Heading AS TreatPlanHeading,
    proctp.ProcTPNum,
    proctp.Priority AS TPPriority,
    proctp.PatAmt AS TPPatientAmount,
    
    -- Periodontal exam information
    pe.PerioExamNum,
    pe.ExamDate AS PerioExamDate,
    CASE WHEN pe.PerioExamNum IS NOT NULL THEN 
        (SELECT COUNT(*) FROM periomeasure pm WHERE pm.PerioExamNum = pe.PerioExamNum)
    ELSE 0 END AS PerioMeasureCount,
    
    -- Payment information
    COALESCE(pa.total_paid, 0) AS TotalPaid,
    COALESCE(pa.insurance_paid, 0) AS InsurancePaid,
    COALESCE(pa.direct_paid, 0) AS DirectPaid,
    
    -- Appointment information if available
    apt.AptDateTime,
    apt.AptStatus
FROM procedurelog pl
JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
LEFT JOIN patient pat ON pl.PatNum = pat.PatNum
LEFT JOIN provider prov ON pl.ProvNum = prov.ProvNum

-- Treatment plan linkage
LEFT JOIN (
    SELECT proctp.ProcNumOrig, proctp.TreatPlanNum, proctp.ProcTPNum, proctp.Priority, proctp.PatAmt
    FROM proctp
    WHERE proctp.ProcNumOrig > 0
) proctp ON pl.ProcNum = proctp.ProcNumOrig
LEFT JOIN treatplan tp ON proctp.TreatPlanNum = tp.TreatPlanNum

-- Periodontal exam linkage (most recent exam before procedure date)
LEFT JOIN (
    SELECT 
        pe1.PerioExamNum, 
        pe1.PatNum, 
        pe1.ExamDate, 
        pe1.ProvNum
    FROM perioexam pe1
    INNER JOIN (
        SELECT PatNum, MAX(ExamDate) as MaxExamDate
        FROM perioexam 
        GROUP BY PatNum
    ) pe2 ON pe1.PatNum = pe2.PatNum AND pe1.ExamDate = pe2.MaxExamDate
) pe ON pl.PatNum = pe.PatNum AND (pe.ExamDate IS NULL OR pe.ExamDate <= pl.ProcDate)

-- Payment information
LEFT JOIN (
    -- Subquery for payment data
    SELECT 
        ProcNum,
        SUM(InsPayAmt) AS insurance_paid,
        SUM(SplitAmt) AS direct_paid,
        SUM(InsPayAmt) + SUM(SplitAmt) AS total_paid
    FROM (
        SELECT 
            ProcNum,
            0 AS InsPayAmt,
            SplitAmt
        FROM paysplit
        WHERE ProcNum > 0
        UNION ALL
        SELECT 
            ProcNum,
            InsPayAmt,
            0 AS SplitAmt
        FROM claimproc
        WHERE ProcNum > 0 AND InsPayAmt <> 0
    ) AS payments
    GROUP BY ProcNum
) AS pa ON pl.ProcNum = pa.ProcNum

-- Appointment information
LEFT JOIN appointment apt ON pl.AptNum = apt.AptNum

WHERE pl.ProcDate >= '{{START_DATE}}' AND pl.ProcDate < '{{END_DATE}}'
ORDER BY pl.ProcDate DESC, pl.ProcNum DESC;
