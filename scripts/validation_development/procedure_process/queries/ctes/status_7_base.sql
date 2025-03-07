-- Dependent CTEs: DateParams
-- Date range: 2024-01-01 to 2025-01-01
-- Description: Base query for Status 7 procedures
Status7Base AS (
    SELECT 
        pl.*,
        pc.ProcCode,
        pc.Descript AS ProcDescription,
        pc.ProcCat,
        pat.PatStatus,
        prov.Abbr AS ProviderAbbr,
        -- Add daily procedure count for anomaly detection
        COUNT(*) OVER (PARTITION BY pl.PatNum, pl.ProcDate) as procs_per_day,
        -- Add category metrics
        COUNT(*) OVER (PARTITION BY pl.PatNum, pc.ProcCat) as procs_per_category,
        COUNT(*) OVER (PARTITION BY pl.PatNum, pc.ProcCat, pl.ProcDate) as procs_per_category_per_day,
        -- Track if procedure has treatment plan
        CASE WHEN tpa.TreatPlanAttachNum IS NOT NULL THEN 1 ELSE 0 END as has_treatment_plan,
        tp.DateTP as treatment_plan_date,
        -- Track if procedure has appointment
        CASE WHEN apt.AptNum IS NOT NULL THEN 1 ELSE 0 END as has_appointment,
        apt.AptDateTime as appointment_date,
        -- Add volume classification
        CASE 
            WHEN COUNT(*) OVER (PARTITION BY pl.PatNum, pl.ProcDate) > 100 THEN 'Extreme'
            WHEN COUNT(*) OVER (PARTITION BY pl.PatNum, pl.ProcDate) > 50 THEN 'High'
            WHEN COUNT(*) OVER (PARTITION BY pl.PatNum, pl.ProcDate) > 20 THEN 'Medium'
            ELSE 'Normal'
        END as volume_flag
    FROM procedurelog pl
    CROSS JOIN DateParams dp
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN patient pat ON pl.PatNum = pat.PatNum
    LEFT JOIN provider prov ON pl.ProvNum = prov.ProvNum
    -- Join with treatment plan attachment and plan
    LEFT JOIN treatplanattach tpa ON pl.ProcNum = tpa.ProcNum
    LEFT JOIN treatplan tp ON tpa.TreatPlanNum = tp.TreatPlanNum 
        AND tp.DateTP >= dp.start_date 
        AND tp.DateTP < dp.end_date
    -- Join with appointment table
    LEFT JOIN appointment apt ON pl.AptNum = apt.AptNum 
        AND apt.AptDateTime >= dp.start_date 
        AND apt.AptDateTime < dp.end_date
    WHERE pl.ProcStatus = 7
    AND pl.ProcDate >= dp.start_date 
    AND pl.ProcDate < dp.end_date
)