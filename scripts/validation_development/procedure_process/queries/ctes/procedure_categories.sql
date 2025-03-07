-- PROCEDURE CATEGORIES
-- Categorizes procedures based on ADA procedure code ranges
-- Dependent CTEs: base_procedures.sql
ProcedureCategories AS (
    SELECT 
        bp.ProvNum,
        CASE 
            WHEN pc.ProcCode LIKE 'D0%' THEN 'Diagnostic'
            WHEN pc.ProcCode LIKE 'D1%' THEN 'Preventive'
            WHEN pc.ProcCode LIKE 'D2%' THEN 'Restorative'
            WHEN pc.ProcCode LIKE 'D3%' THEN 'Endodontics'
            WHEN pc.ProcCode LIKE 'D4%' THEN 'Periodontics'
            WHEN pc.ProcCode LIKE 'D5%' THEN 'Prosthodontics-Removable'
            WHEN pc.ProcCode LIKE 'D6%' THEN 'Implant Services'
            WHEN pc.ProcCode LIKE 'D7%' THEN 'Oral Surgery'
            WHEN pc.ProcCode LIKE 'D8%' THEN 'Orthodontics'
            WHEN pc.ProcCode LIKE 'D9%' THEN 'Adjunctive Services'
            ELSE 'Other'
        END AS ProcCat,
        COUNT(*) AS CategoryCount,
        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY bp.ProvNum), 1) AS CategoryPct,
        SUM(bp.ProcFee) AS CategoryFees,
        COUNT(DISTINCT bp.CodeNum) AS UniqueCodes,
        COUNT(DISTINCT bp.PatNum) AS UniquePatients,
        -- Status breakdown within category
        SUM(CASE WHEN bp.ProcStatus = 2 THEN 1 ELSE 0 END) AS CompletedCount,
        ROUND(100.0 * 
            SUM(CASE WHEN bp.ProcStatus = 2 THEN 1 ELSE 0 END) / 
            NULLIF(COUNT(*), 0), 1
        ) AS CompletionRate
    FROM BaseProcedures bp
    JOIN procedurecode pc ON bp.CodeNum = pc.CodeNum
    WHERE bp.ProvNum > 0
      AND bp.CodeCategory = 'Standard'  -- Exclude non-standard procedures
    GROUP BY 
        bp.ProvNum,
        CASE 
            WHEN pc.ProcCode LIKE 'D0%' THEN 'Diagnostic'
            WHEN pc.ProcCode LIKE 'D1%' THEN 'Preventive'
            WHEN pc.ProcCode LIKE 'D2%' THEN 'Restorative'
            WHEN pc.ProcCode LIKE 'D3%' THEN 'Endodontics'
            WHEN pc.ProcCode LIKE 'D4%' THEN 'Periodontics'
            WHEN pc.ProcCode LIKE 'D5%' THEN 'Prosthodontics-Removable'
            WHEN pc.ProcCode LIKE 'D6%' THEN 'Implant Services'
            WHEN pc.ProcCode LIKE 'D7%' THEN 'Oral Surgery'
            WHEN pc.ProcCode LIKE 'D8%' THEN 'Orthodontics'
            WHEN pc.ProcCode LIKE 'D9%' THEN 'Adjunctive Services'
            ELSE 'Other'
        END
) 