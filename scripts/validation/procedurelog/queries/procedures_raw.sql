-- Raw Procedure Data Query
-- Extracts detailed procedure records with all relevant columns

SELECT 
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
    pl.Note,
    pl.ClinicNum,
    pl.UnitQty,
    pl.Urgency,
    pl.Discount,
    pc.ProcCode,
    pc.Descript AS ProcDescription,
    pc.TreatArea,
    pat.LName AS PatientLastName,
    pat.FName AS PatientFirstName,
    prov.Abbr AS ProviderAbbr,
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
LEFT JOIN appointment apt ON pl.AptNum = apt.AptNum
WHERE pl.ProcDate >= '{{START_DATE}}' AND pl.ProcDate < '{{END_DATE}}'
ORDER BY pl.ProcDate DESC, pl.ProcNum DESC
LIMIT 100000; -- Add a limit to prevent excessively large results
